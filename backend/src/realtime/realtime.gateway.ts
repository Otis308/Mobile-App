import { OnModuleDestroy } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { JwtPayload } from '../common/interfaces/jwt-payload.interface';
import { InjectModel } from '@nestjs/mongoose';
import { Project, ProjectDocument } from '../projects/schemas/project.schema';
import { Model, Types } from 'mongoose';

@WebSocketGateway({
  namespace: '/realtime',
  cors: { origin: '*' },
  pingInterval: 10000,
  pingTimeout: 8000,
})
export class RealtimeGateway implements OnGatewayConnection, OnModuleDestroy {
  @WebSocketServer() server!: Server;
  private readonly presenceTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly jwt: JwtService,
    @InjectModel(Project.name) private readonly projects: Model<ProjectDocument>,
  ) {}

  onModuleDestroy() {
    for (const timer of this.presenceTimers.values()) {
      clearTimeout(timer);
    }
    this.presenceTimers.clear();
  }

  async handleConnection(socket: Socket) {
    try {
      const rawToken =
        socket.handshake.auth?.token ||
        socket.handshake.query?.token ||
        socket.handshake.headers.authorization?.replace('Bearer ', '');
      const token = Array.isArray(rawToken) ? rawToken[0] : (rawToken as string);

      if (!token) {
        socket.disconnect(true);
        return;
      }

      const payload = await this.jwt.verifyAsync<JwtPayload>(token);
      socket.data.userId = payload.sub;

      const leftProjects = new Set<string>();
      socket.on('disconnecting', () => {
        for (const room of socket.rooms) {
          if (room.startsWith('project:')) {
            leftProjects.add(room.slice(8));
          }
        }
      });
      socket.on('disconnect', () => {
        leftProjects.forEach((id) => this.schedulePresence(id));
      });

      await socket.join(`user:${payload.sub}`);

      const mine = await this.projects
        .find({ 'members.userId': new Types.ObjectId(payload.sub) })
        .select('_id')
        .lean();
      const ids = mine.map((p: any) => p._id.toString());
      await Promise.all(ids.map((id) => socket.join(`project:${id}`)));

      socket.emit('connected', { userId: payload.sub });
      ids.forEach((id) => this.schedulePresence(id));
    } catch {
      socket.disconnect(true);
    }
  }

  async onlineUsers(projectId: string): Promise<string[]> {
    const sockets = await this.server.in(`project:${projectId}`).fetchSockets();
    return [...new Set(sockets.map((s) => s.data.userId as string).filter(Boolean))];
  }

  schedulePresence(projectId: string) {
    const existing = this.presenceTimers.get(projectId);
    if (existing) clearTimeout(existing);

    const timer = setTimeout(() => {
      this.presenceTimers.delete(projectId);
      void this.emitPresence(projectId);
    }, 150);
    this.presenceTimers.set(projectId, timer);
  }

  async emitPresence(projectId: string) {
    try {
      const onlineUserIds = await this.onlineUsers(projectId);
      this.server.to(`project:${projectId}`).emit('presence.update', { projectId, onlineUserIds });
    } catch {
      // Bỏ qua lỗi phụ trợ presence
    }
  }

  @SubscribeMessage('presence.sync')
  async syncPresence(
    @ConnectedSocket() socket: Socket,
    @MessageBody() body?: { projectId?: string },
  ) {
    const userId = socket.data.userId as string | undefined;
    if (!userId) return { ok: false };

    if (body?.projectId && Types.ObjectId.isValid(body.projectId)) {
      await socket.join(`project:${body.projectId}`);
      await this.emitPresence(body.projectId);
      return { ok: true };
    }

    const mine = await this.projects
      .find({ 'members.userId': new Types.ObjectId(userId) })
      .select('_id')
      .lean();
    for (const p of mine) {
      const pid = (p as any)._id.toString();
      await socket.join(`project:${pid}`);
      await this.emitPresence(pid);
    }
    return { ok: true };
  }

  @SubscribeMessage('project.join')
  async joinProject(@ConnectedSocket() socket: Socket, @MessageBody() body: { projectId: string }) {
    if (!Types.ObjectId.isValid(body?.projectId)) {
      return { ok: false, message: 'projectId không hợp lệ' };
    }
    const project = await this.projects
      .findOne({
        _id: new Types.ObjectId(body.projectId),
        'members.userId': new Types.ObjectId(socket.data.userId),
      })
      .select('_id')
      .lean();
    if (!project) return { ok: false, message: 'Không có quyền vào dự án' };

    await socket.join(`project:${body.projectId}`);
    this.schedulePresence(body.projectId);
    return { ok: true };
  }

  @SubscribeMessage('project.leave')
  async leaveProject(@ConnectedSocket() _socket: Socket, @MessageBody() body: { projectId: string }) {
    if (body?.projectId && Types.ObjectId.isValid(body.projectId)) {
      this.schedulePresence(body.projectId);
    }
    return { ok: true };
  }

  @SubscribeMessage('auth.logout')
  handleLogout(@ConnectedSocket() socket: Socket) {
    socket.disconnect(true);
    return { ok: true };
  }

  projectRoom(projectId: string, event: string, data: unknown) {
    this.server.to(`project:${projectId}`).emit(event, data);
  }

  userRoom(userId: string, event: string, data: unknown) {
    this.server.to(`user:${userId}`).emit(event, data);
  }

  async addUserToProject(userId: string, projectId: string) {
    const userSockets = await this.server.in(`user:${userId}`).fetchSockets();
    for (const s of userSockets) {
      s.join(`project:${projectId}`);
    }
    await this.emitPresence(projectId);
  }

  async removeUserFromProject(userId: string, projectId: string) {
    const userSockets = await this.server.in(`user:${userId}`).fetchSockets();
    for (const s of userSockets) {
      s.leave(`project:${projectId}`);
    }
    await this.emitPresence(projectId);
  }
}