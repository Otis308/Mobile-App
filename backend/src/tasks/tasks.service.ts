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
  async move(id: string, userId: string, dto: MoveTaskDto) {
    const t = await this.get(id, userId);
    const pid = new Types.ObjectId(t.projectId.toString());

    // Cột đích (trừ thẻ đang kéo), chèn thẻ vào vị trí dto.order
    const dest = await this.model
      .find({ projectId: pid, status: dto.status, _id: { $ne: t._id } })
      .sort({ order: 1, createdAt: 1 }).select('_id').lean();
    const ids = dest.map((x) => x._id);
    ids.splice(Math.min(dto.order, ids.length), 0, t._id);

    const ops: any[] = ids.map((tid, i) => {
      const $set: any = { order: i };
      if (tid.equals(t._id)) {
        $set.status = dto.status;
        if (t.status !== dto.status) $set.completedAt = dto.status === 'done' ? new Date() : null;
      }
      return { updateOne: { filter: { _id: tid }, update: { $set } } };
    });

    // Nếu đổi cột: đánh lại thứ tự cột cũ cho liền mạch
    if (t.status !== dto.status) {
      const src = await this.model
        .find({ projectId: pid, status: t.status, _id: { $ne: t._id } })
        .sort({ order: 1, createdAt: 1 }).select('_id').lean();
      src.forEach((x, i) => ops.push({ updateOne: { filter: { _id: x._id }, update: { $set: { order: i } } } }));
    }

    await this.model.bulkWrite(ops);
    const updated = await this.model.findById(id).lean();
    this.realtime.projectRoom(pid.toString(), 'task.moved', updated);
    return updated;
  }
  async update(id: string, userId: string, dto: UpdateTaskDto) {
    const t = await this.get(id, userId);
    const { status: _ignored, ...rest } = dto; // đổi trạng thái chỉ đi qua /move
    const patch: Record<string, any> = { ...rest };

    if (dto.assigneeId !== undefined) {
      if (dto.assigneeId) {
        await this.projects.member(t.projectId.toString(), dto.assigneeId);
        patch.assigneeId = new Types.ObjectId(dto.assigneeId);
      } else {
        patch.assigneeId = null; // client gửi null/'' = bỏ giao
      }
    }
    if (dto.dueDate !== undefined) {
      patch.dueDate = dto.dueDate ? new Date(dto.dueDate) : null;
      patch.dueReminderSent = false;
    }
    const updated = await this.model.findByIdAndUpdate(id, patch, { new: true, runValidators: true }).lean();
    this.realtime.projectRoom(t.projectId.toString(), 'task.updated', updated);

    const newAssignee = dto.assigneeId && dto.assigneeId !== userId && dto.assigneeId !== t.assigneeId?.toString();
    if (newAssignee) {
      const message = `Bạn được giao: ${t.title}`;
      await this.notifications.create(dto.assigneeId!, 'TASK_ASSIGNED', message, `/tasks/${id}`);
      this.realtime.userRoom(dto.assigneeId!, 'notification.created', { type: 'TASK_ASSIGNED', message });
    }
    return updated;
  }
  async remove(id:string,userId:string){ const t=await this.get(id,userId); const manager=await this.projects.canManage(t.projectId.toString(),userId); if(!manager && t.createdBy.toString()!==userId) throw new ForbiddenException('Bạn không có quyền xóa task'); await this.model.findByIdAndDelete(id); this.realtime.projectRoom(t.projectId.toString(),'task.deleted',{taskId:id}); return {ok:true}; }
}
