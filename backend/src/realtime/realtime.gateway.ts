import { ConnectedSocket, MessageBody, OnGatewayConnection, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { JwtPayload } from '../common/interfaces/jwt-payload.interface';
import { InjectModel } from '@nestjs/mongoose';
import { Project, ProjectDocument } from '../projects/schemas/project.schema';
import { Model, Types } from 'mongoose';
import { NotificationsModule } from '../notifications/notifications.module';

@WebSocketGateway({ namespace: '/realtime', cors: { origin: '*' } })
export class RealtimeGateway implements OnGatewayConnection {
  @WebSocketServer() server!: Server;
  constructor(private readonly jwt: JwtService, @InjectModel(Project.name) private readonly projects: Model<ProjectDocument>) {}

  async handleConnection(socket: Socket) {
    try {
      const token = (socket.handshake.auth?.token || socket.handshake.headers.authorization?.replace('Bearer ', '')) as string;
      const payload = await this.jwt.verifyAsync<JwtPayload>(token);
      socket.data.userId = payload.sub;

      // Ghi nhớ các dự án để cập nhật trạng thái online khi ngắt kết nối
      const leftProjects: string[] = [];
      socket.on('disconnecting', () => {
        for (const room of socket.rooms) {
          if (room.startsWith('project:')) leftProjects.push(room.slice(8));
        }
      });
      socket.on('disconnect', () => {
        leftProjects.forEach((id) => void this.emitPresence(id));
      });

      await socket.join(`user:${payload.sub}`);
      // Tự động vào phòng của mọi dự án mà user là thành viên
      const mine = await this.projects.find({ 'members.userId': new Types.ObjectId(payload.sub) }).select('_id').lean();
      const ids = mine.map((p: any) => p._id.toString());
      await Promise.all(ids.map((id) => socket.join(`project:${id}`)));

      socket.emit('connected', { userId: payload.sub });
      await Promise.all(ids.map((id) => this.emitPresence(id)));
    } catch {
      socket.disconnect(true);
    }
  }

  async onlineUsers(projectId: string): Promise<string[]> {
    const sockets = await this.server.in(`project:${projectId}`).fetchSockets();
    return [...new Set(sockets.map((s) => s.data.userId as string).filter(Boolean))];
  }

  async emitPresence(projectId: string) {
    try {
      const onlineUserIds = await this.onlineUsers(projectId);
      this.server.to(`project:${projectId}`).emit('presence.update', { projectId, onlineUserIds });
    } catch {
      // bỏ qua: presence chỉ là thông tin phụ
    }
  }

  @SubscribeMessage('project.join')
  async joinProject(@ConnectedSocket() socket: Socket, @MessageBody() body: { projectId: string }) {
    if (!Types.ObjectId.isValid(body?.projectId)) return { ok:false, message:'projectId không hợp lệ' };
    const project = await this.projects.findOne({ _id: body.projectId, 'members.userId': new Types.ObjectId(socket.data.userId) }).lean();
    if (!project) return { ok:false, message:'Không có quyền vào dự án' };
    socket.join(`project:${body.projectId}`); return { ok:true };
  }

  @SubscribeMessage('project.leave')
  leaveProject(@ConnectedSocket() socket: Socket, @MessageBody() body: { projectId: string }) {
    if (body?.projectId) socket.leave(`project:${body.projectId}`);
    return { ok: true };
  }
  
  projectRoom(projectId: string, event: string, data: unknown) { this.server.to(`project:${projectId}`).emit(event, data); }
  userRoom(userId: string, event: string, data: unknown) { this.server.to(`user:${userId}`).emit(event, data); }

  
  addUserToProject(userId: string, projectId: string) {
    this.server.in(`user:${userId}`).socketsJoin(`project:${projectId}`);
    void this.emitPresence(projectId);
  }

  removeUserFromProject(userId: string, projectId: string) {
    this.server.in(`user:${userId}`).socketsLeave(`project:${projectId}`);
    void this.emitPresence(projectId);
  }
  
}

