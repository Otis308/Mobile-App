import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Task, TaskDocument } from './schemas/task.schema';
import { CreateTaskDto } from './dto/create-task.dto';
import { UpdateTaskDto } from './dto/update-task.dto';
import { MoveTaskDto } from './dto/move-task.dto';
import { ProjectsService } from '../projects/projects.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class TasksService {
  constructor(@InjectModel(Task.name) private readonly model: Model<TaskDocument>, private readonly projects: ProjectsService, private readonly realtime: RealtimeGateway, private readonly notifications: NotificationsService) {}
  async list(projectId: string, userId: string) { await this.projects.member(projectId,userId); return this.model.find({ projectId:new Types.ObjectId(projectId) }).sort({status:1,order:1,createdAt:1}).lean().exec(); }
  async get(id:string,userId:string){ const t=await this.model.findById(id).lean(); if(!t)throw new NotFoundException('Không tìm thấy công việc'); await this.projects.member(t.projectId.toString(),userId); return t; }
  async create(projectId:string,userId:string,dto:CreateTaskDto){ await this.projects.member(projectId,userId); if(dto.assigneeId && !(await this.projects.member(projectId,dto.assigneeId).catch(()=>null))) throw new BadRequestException('Người được giao chưa thuộc dự án'); const count=await this.model.countDocuments({projectId:new Types.ObjectId(projectId),status:dto.status??'todo'}); const t=await this.model.create({...dto,projectId:new Types.ObjectId(projectId),createdBy:new Types.ObjectId(userId),assigneeId:dto.assigneeId?new Types.ObjectId(dto.assigneeId):undefined,dueDate:dto.dueDate?new Date(dto.dueDate):undefined,order:count}); const result=t.toObject(); this.realtime.projectRoom(projectId,'task.created',result); return result; }
  async update(id:string,userId:string,dto:UpdateTaskDto){ const t=await this.get(id,userId); if(dto.assigneeId) await this.projects.member(t.projectId.toString(),dto.assigneeId); const updated=await this.model.findByIdAndUpdate(id,{...dto,dueDate:dto.dueDate?new Date(dto.dueDate):undefined,assigneeId:dto.assigneeId?new Types.ObjectId(dto.assigneeId):undefined},{new:true,runValidators:true}).lean(); this.realtime.projectRoom(t.projectId.toString(),'task.updated',updated); if(dto.assigneeId && dto.assigneeId!==userId) await this.notifications.create(dto.assigneeId,'TASK_ASSIGNED',`Bạn được giao: ${t.title}`,`/tasks/${id}`); return updated; }
  async move(id:string,userId:string,dto:MoveTaskDto){ const t=await this.get(id,userId); const updated=await this.model.findByIdAndUpdate(id,{status:dto.status,order:dto.order},{new:true}).lean(); this.realtime.projectRoom(t.projectId.toString(),'task.moved',updated); return updated; }
  async remove(id:string,userId:string){ const t=await this.get(id,userId); const manager=await this.projects.canManage(t.projectId.toString(),userId); if(!manager && t.createdBy.toString()!==userId) throw new ForbiddenException('Bạn không có quyền xóa task'); await this.model.findByIdAndDelete(id); this.realtime.projectRoom(t.projectId.toString(),'task.deleted',{taskId:id}); return {ok:true}; }
}
