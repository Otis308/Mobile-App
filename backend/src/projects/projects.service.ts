import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Project, ProjectDocument } from './schemas/project.schema';
import { CreateProjectDto } from './dto/create-project.dto';
import { UpdateProjectDto } from './dto/update-project.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { UsersService } from '../users/users.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class ProjectsService {
  constructor(@InjectModel(Project.name) private readonly model: Model<ProjectDocument>, private readonly users: UsersService, private readonly realtime: RealtimeGateway, private readonly notifications: NotificationsService) {}
  async listForUser(userId: string) { return this.model.find({ 'members.userId': new Types.ObjectId(userId) }).sort({ updatedAt: -1 }).lean().exec(); }
  async get(id: string) { const p = await this.model.findById(id).lean().exec(); if (!p) throw new NotFoundException('Không tìm thấy dự án'); return p; }
  async member(id: string, userId: string) { const p = await this.model.findById(id).lean().exec(); if (!p) throw new NotFoundException('Không tìm thấy dự án'); const member = p.members.find((m:any) => m.userId.toString() === userId); if (!member) throw new ForbiddenException('Bạn không thuộc dự án này'); return { project: p, member }; }
  async canManage(id: string, userId: string) { const { project, member } = await this.member(id,userId); return project.ownerId.toString() === userId || member.role === 'owner' || member.role === 'manager'; }
  async create(userId: string, dto: CreateProjectDto) { const p = await this.model.create({ ...dto, ownerId: new Types.ObjectId(userId), members: [{ userId: new Types.ObjectId(userId), role: 'owner' }] }); return p.toObject(); }
  async update(id: string, userId: string, dto: UpdateProjectDto) { if (!(await this.canManage(id,userId))) throw new ForbiddenException('Chỉ owner/manager mới được sửa dự án'); const p = await this.model.findByIdAndUpdate(id,dto,{new:true,runValidators:true}).lean(); if (!p) throw new NotFoundException('Không tìm thấy dự án'); this.realtime.projectRoom(id, 'project.updated', p); return p; }
  async addMember(id: string, actorId: string, dto: AddMemberDto) {
    if (!(await this.canManage(id,actorId))) throw new ForbiddenException('Bạn không có quyền thêm thành viên');
    const user = await this.users.getById(dto.userId);
    const p = await this.model.findById(id); if (!p) throw new NotFoundException('Không tìm thấy dự án');
    if (p.members.some((m:any) => m.userId.toString() === dto.userId)) throw new BadRequestException('Người dùng đã ở trong dự án');
    p.members.push({ userId: new Types.ObjectId(dto.userId), role: dto.role, joinedAt: new Date() }); await p.save();
    const result = await this.model.findById(id).lean();
    await this.notifications.create(user._id.toString(), 'MEMBER_ADDED', `Bạn được thêm vào dự án ${p.name}`, `/projects/${id}`);
    this.realtime.projectRoom(id,'project.memberAdded',result);
    this.realtime.userRoom(user._id.toString(),'notification.created',{ type:'MEMBER_ADDED', message:`Bạn được thêm vào dự án ${p.name}` });
    return result;
  }
  async removeProject(id:string,userId:string){ if(!(await this.canManage(id,userId))) throw new ForbiddenException('Bạn không có quyền xóa dự án'); const p=await this.model.findByIdAndDelete(id).lean(); if(!p) throw new NotFoundException('Không tìm thấy dự án'); this.realtime.projectRoom(id,'project.deleted',{projectId:id}); return {ok:true}; }
  async removeMember(id: string, actorId: string, userId: string) { if (!(await this.canManage(id,actorId))) throw new ForbiddenException('Bạn không có quyền'); const p = await this.model.findById(id); if (!p) throw new NotFoundException('Không tìm thấy dự án'); if (p.ownerId.toString()===userId) throw new BadRequestException('Không thể xóa owner'); p.members = p.members.filter((m:any) => m.userId.toString()!==userId) as any; await p.save(); const result=await this.model.findById(id).lean(); this.realtime.projectRoom(id,'project.memberRemoved',{projectId:id,userId}); return result; }
}
