import { ConnectedSocket, MessageBody, OnGatewayConnection, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { JwtPayload } from '../common/interfaces/jwt-payload.interface';
import { InjectModel } from '@nestjs/mongoose';
import { Project, ProjectDocument } from '../projects/schemas/project.schema';
import { Model, Types } from 'mongoose';

@WebSocketGateway({ namespace: '/realtime', cors: { origin: '*' } })
export class RealtimeGateway implements OnGatewayConnection {
  @WebSocketServer() server!: Server;
  constructor(private readonly jwt: JwtService, @InjectModel(Project.name) private readonly projects: Model<ProjectDocument>) {}

  async handleConnection(socket: Socket) {
    try {
      const token = (socket.handshake.auth?.token || socket.handshake.headers.authorization?.replace('Bearer ', '')) as string;
      const payload = await this.jwt.verifyAsync<JwtPayload>(token);
      socket.data.userId = payload.sub;
      socket.join(`user:${payload.sub}`);
      socket.emit('connected', { userId: payload.sub });
    } catch { socket.disconnect(true); }
  }

  @SubscribeMessage('project.join')
  async joinProject(@ConnectedSocket() socket: Socket, @MessageBody() body: { projectId: string }) {
    if (!Types.ObjectId.isValid(body?.projectId)) return { ok:false, message:'projectId không hợp lệ' };
    const project = await this.projects.findOne({ _id: body.projectId, 'members.userId': new Types.ObjectId(socket.data.userId) }).lean();
    if (!project) return { ok:false, message:'Không có quyền vào dự án' };
    socket.join(`project:${body.projectId}`); return { ok:true };
  }

  projectRoom(projectId: string, event: string, data: unknown) { this.server.to(`project:${projectId}`).emit(event, data); }
  userRoom(userId: string, event: string, data: unknown) { this.server.to(`user:${userId}`).emit(event, data); }
}
