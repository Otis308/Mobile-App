import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
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
  private readonly projectLocks = new Map<string, Promise<unknown>>();

  constructor(
    @InjectModel(Task.name) private readonly model: Model<TaskDocument>,
    private readonly projects: ProjectsService,
    private readonly realtime: RealtimeGateway,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Khóa tuần tự theo từng projectId để ngăn chặn tuyệt đối Race Condition
   * khi nhiều người dùng cùng kéo thả thẻ Kanban hoặc tạo task đồng thời.
   */
  private async withProjectLock<T>(projectId: string, fn: () => Promise<T>): Promise<T> {
    const prev = this.projectLocks.get(projectId) ?? Promise.resolve();
    let release!: () => void;
    const current = new Promise<void>((resolve) => {
      release = resolve;
    });
    const chain = prev.then(() => current);
    this.projectLocks.set(projectId, chain);

    await prev;
    try {
      return await fn();
    } finally {
      release();
      if (this.projectLocks.get(projectId) === chain) {
        this.projectLocks.delete(projectId);
      }
    }
  }

  async list(projectId: string, userId: string) {
    await this.projects.member(projectId, userId);
    return this.model
      .find({ projectId: new Types.ObjectId(projectId) })
      .sort({ status: 1, order: 1, createdAt: 1 })
      .lean()
      .exec();
  }

  async listAllForUser(userId: string) {
    const userProjects = await this.projects.listForUser(userId);
    if (!userProjects.length) return [];
    const projectIds = userProjects.map((p: any) => p._id);
    return this.model
      .find({ projectId: { $in: projectIds } })
      .sort({ dueDate: 1, status: 1, order: 1 })
      .lean()
      .exec();
  }

  async get(id: string, userId: string) {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('ID công việc không hợp lệ');
    }
    const t = await this.model.findById(id).lean();
    if (!t) throw new NotFoundException('Không tìm thấy công việc');
    await this.projects.member(t.projectId.toString(), userId);
    return t;
  }

  async create(projectId: string, userId: string, dto: CreateTaskDto) {
    await this.projects.member(projectId, userId);
    if (dto.assigneeId) {
      const isMember = await this.projects.member(projectId, dto.assigneeId).catch(() => null);
      if (!isMember) throw new BadRequestException('Người được giao chưa thuộc dự án');
    }

    return this.withProjectLock(projectId, async () => {
      const pid = new Types.ObjectId(projectId);
      const status = dto.status ?? 'todo';
      const lastTask = await this.model
        .findOne({ projectId: pid, status })
        .sort({ order: -1 })
        .select('order')
        .lean();
      const nextOrder = lastTask ? (lastTask.order ?? 0) + 1 : 0;

      const t = await this.model.create({
        ...dto,
        projectId: pid,
        status,
        createdBy: new Types.ObjectId(userId),
        assigneeId: dto.assigneeId ? new Types.ObjectId(dto.assigneeId) : undefined,
        dueDate: dto.dueDate ? new Date(dto.dueDate) : undefined,
        order: nextOrder,
      });

      const result = t.toObject();
      this.realtime.projectRoom(projectId, 'task.created', result);

      if (dto.assigneeId && dto.assigneeId !== userId) {
        const message = `Bạn được giao công việc mới: ${t.title}`;
        await this.notifications.create(dto.assigneeId, 'TASK_ASSIGNED', message, `/tasks/${t._id}`);
        this.realtime.userRoom(dto.assigneeId, 'notification.created', {
          type: 'TASK_ASSIGNED',
          message,
        });
      }

      return result;
    });
  }

  async move(id: string, userId: string, dto: MoveTaskDto) {
    const initialTask = await this.get(id, userId);
    const projectIdStr = initialTask.projectId.toString();

    return this.withProjectLock(projectIdStr, async () => {
      const t = await this.model.findById(id).lean();
      if (!t) throw new NotFoundException('Không tìm thấy công việc');

      const pid = new Types.ObjectId(projectIdStr);
      const dest = await this.model
        .find({ projectId: pid, status: dto.status, _id: { $ne: t._id } })
        .sort({ order: 1, createdAt: 1 })
        .select('_id')
        .lean();

      const ids = dest.map((x) => x._id);
      const targetIndex = Math.max(0, Math.min(dto.order, ids.length));
      ids.splice(targetIndex, 0, t._id);

      const ops: any[] = ids.map((tid, i) => {
        const $set: any = { order: i };
        if (tid.equals(t._id)) {
          $set.status = dto.status;
          if (t.status !== dto.status) {
            $set.completedAt = dto.status === 'done' ? new Date() : null;
          }
        }
        return { updateOne: { filter: { _id: tid }, update: { $set } } };
      });

      if (t.status !== dto.status) {
        const src = await this.model
          .find({ projectId: pid, status: t.status, _id: { $ne: t._id } })
          .sort({ order: 1, createdAt: 1 })
          .select('_id')
          .lean();
        src.forEach((x, i) =>
          ops.push({ updateOne: { filter: { _id: x._id }, update: { $set: { order: i } } } }),
        );
      }

      if (ops.length > 0) {
        await this.model.bulkWrite(ops, { ordered: false });
      }

      const updated = await this.model.findById(id).lean();
      this.realtime.projectRoom(projectIdStr, 'task.moved', updated);
      return updated;
    });
  }

  async update(id: string, userId: string, dto: UpdateTaskDto) {
    const t = await this.get(id, userId);
    const projectIdStr = t.projectId.toString();
    const isManager = await this.projects.canManage(projectIdStr, userId);
    const isCreatorOrAssignee =
      t.createdBy.toString() === userId || t.assigneeId?.toString() === userId;

    if (!isManager && !isCreatorOrAssignee) {
      throw new ForbiddenException(
        'Chỉ quản lý dự án, người tạo hoặc người được giao mới được chỉnh sửa công việc này',
      );
    }

    if (dto.expectedUpdatedAt && (t as any).updatedAt) {
      const clientTime = new Date(dto.expectedUpdatedAt).getTime();
      const serverTime = new Date((t as any).updatedAt).getTime();
      if (Math.abs(serverTime - clientTime) > 1000) {
        throw new ConflictException(
          'Công việc vừa được thành viên khác cập nhật. Vui lòng tải lại trước khi lưu.',
        );
      }
    }

    const { status: _ignored, expectedUpdatedAt: _exp, ...rest } = dto;
    const patch: Record<string, any> = { ...rest };

    if (dto.assigneeId !== undefined) {
      if (!isManager && dto.assigneeId && dto.assigneeId !== userId) {
        throw new ForbiddenException('Thành viên chỉ có thể tự nhận việc hoặc nhờ Quản lý phân công');
      }
      if (dto.assigneeId) {
        await this.projects.member(projectIdStr, dto.assigneeId);
        patch.assigneeId = new Types.ObjectId(dto.assigneeId);
      } else {
        patch.assigneeId = null;
      }
    }

    if (dto.dueDate !== undefined) {
      patch.dueDate = dto.dueDate ? new Date(dto.dueDate) : null;
      patch.dueReminderSent = false;
    }

    const updated = await this.model
      .findByIdAndUpdate(id, patch, { new: true, runValidators: true })
      .lean();
    if (!updated) throw new NotFoundException('Không tìm thấy công việc');

    this.realtime.projectRoom(projectIdStr, 'task.updated', updated);

    const newAssignee =
      dto.assigneeId && dto.assigneeId !== userId && dto.assigneeId !== t.assigneeId?.toString();
    if (newAssignee) {
      const message = `Bạn được giao: ${updated.title}`;
      await this.notifications.create(dto.assigneeId!, 'TASK_ASSIGNED', message, `/tasks/${id}`);
      this.realtime.userRoom(dto.assigneeId!, 'notification.created', {
        type: 'TASK_ASSIGNED',
        message,
      });
    }
    return updated;
  }

  async remove(id: string, userId: string) {
    const t = await this.get(id, userId);
    const projectIdStr = t.projectId.toString();
    const manager = await this.projects.canManage(projectIdStr, userId);
    if (!manager && t.createdBy.toString() !== userId) {
      throw new ForbiddenException('Bạn không có quyền xóa công việc này');
    }

    await this.withProjectLock(projectIdStr, async () => {
      await this.model.findByIdAndDelete(id);
    });

    this.realtime.projectRoom(projectIdStr, 'task.deleted', {
      taskId: id,
      projectId: projectIdStr,
    });
    return { ok: true };
  }
}