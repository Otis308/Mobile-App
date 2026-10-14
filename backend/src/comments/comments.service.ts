// File: backend/src/comments/comments.service.ts
import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Comment, CommentDocument } from './schemas/comment.schema';
import { TasksService } from '../tasks/tasks.service';
import { ProjectsService } from '../projects/projects.service';
import { CreateCommentDto } from './dto/create-comment.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class CommentsService {
  constructor(
    @InjectModel(Comment.name) private readonly model: Model<CommentDocument>,
    private readonly tasks: TasksService,
    private readonly projects: ProjectsService,
    private readonly realtime: RealtimeGateway,
    private readonly notifications: NotificationsService,
  ) {}

  async list(taskId: string, userId: string) {
    await this.tasks.get(taskId, userId);

    return this.model
      .find({ taskId: new Types.ObjectId(taskId) })
      .sort({ createdAt: 1 })
      .lean()
      .exec();
  }

  async create(taskId: string, userId: string, dto: CreateCommentDto) {
    const task = await this.tasks.get(taskId, userId);

    const c = await this.model.create({
      taskId: new Types.ObjectId(taskId),
      authorId: new Types.ObjectId(userId),
      content: dto.content.trim(),
    });

    const result = c.toObject();
    this.realtime.projectRoom(task.projectId.toString(), 'comment.created', result);

    const targets = new Set<string>();
    if (task.assigneeId) targets.add(task.assigneeId.toString());
    if (task.createdBy) targets.add(task.createdBy.toString());
    targets.delete(userId);

    for (const uid of targets) {
      const message = `Có bình luận mới trong: ${task.title}`;
      await this.notifications.create(uid, 'COMMENT', message, `/tasks/${taskId}`);
      this.realtime.userRoom(uid, 'notification.created', { type: 'COMMENT', message });
    }

    return result;
  }

  async remove(id: string, userId: string) {
    const c = await this.model.findById(id).lean();
    if (!c) {
      throw new NotFoundException('Không tìm thấy bình luận');
    }

    const task = await this.tasks.get(c.taskId.toString(), userId);
    const isAuthor = c.authorId.toString() === userId;
    const canManage = await this.projects.canManage(task.projectId.toString(), userId);

    if (!isAuthor && !canManage) {
      throw new ForbiddenException('Bạn không có quyền xóa bình luận này');
    }

    await this.model.findByIdAndDelete(id);
    this.realtime.projectRoom(task.projectId.toString(), 'comment.deleted', {
      commentId: id,
      taskId: c.taskId.toString(),
    });
    return { ok: true };
  }
}