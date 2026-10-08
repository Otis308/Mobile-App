import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Comment, CommentDocument } from './schemas/comment.schema';
import { TasksService } from '../tasks/tasks.service';
import { CreateCommentDto } from './dto/create-comment.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class CommentsService {
  constructor(
    @InjectModel(Comment.name) private readonly model: Model<CommentDocument>,
    private readonly tasks: TasksService,
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
      content: dto.content,
    });
    
    const result = c.toObject();
    
    // 1. Gửi realtime event
    this.realtime.projectRoom(task.projectId.toString(), 'comment.created', result);
    
    // 2. Xử lý logic gửi thông báo
    const targets = new Set<string>();

    const assigneeId = task.assigneeId;
    if (assigneeId) {
      targets.add(assigneeId.toString());
    }
    
    const createdBy = task.createdBy;
    if (createdBy) {
      targets.add(createdBy.toString());
    }

    targets.delete(userId); // Không gửi thông báo cho chính người vừa comment
    
    for (const uid of targets) {
      const message = `Có bình luận mới trong: ${task.title}`;
      await this.notifications.create(uid, 'COMMENT', message, `/tasks/${taskId}`);
      this.realtime.userRoom(uid, 'notification.created', { type: 'COMMENT', message });
    }

    // 3. Trả về kết quả sau khi đã chạy xong thông báo
    return result;
  }

  async remove(id: string, userId: string) {
    const c = await this.model.findById(id).lean();
    
    if (!c) {
      throw new NotFoundException('Không tìm thấy bình luận');
    }
    
    if (c.authorId.toString() !== userId) {
      throw new ForbiddenException('Bạn chỉ được xóa bình luận của mình');
    }
    
    await this.model.findByIdAndDelete(id);
    return { ok: true };
  }
}