import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Task, TaskDocument } from './schemas/task.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class DeadlineReminderService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DeadlineReminderService.name);
  private timer?: NodeJS.Timeout;

  constructor(
    @InjectModel(Task.name) private readonly model: Model<TaskDocument>,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  onModuleInit() {
    this.timer = setInterval(() => void this.run(), 10 * 60 * 1000); // mỗi 10 phút
    setTimeout(() => void this.run(), 15_000); // chạy thử sau khi server khởi động 15 giây
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async run() {
    try {
      const now = new Date();
      const soon = new Date(now.getTime() + 24 * 3600 * 1000);
      const tasks = await this.model
        .find({
          dueDate: { $gte: now, $lte: soon },
          status: { $ne: 'done' },
          assigneeId: { $ne: null },
          dueReminderSent: { $ne: true },
        })
        .limit(200)
        .lean();

      for (const t of tasks) {
        const uid = t.assigneeId!.toString();
        const message = `Sắp đến hạn: ${t.title}`;
        await this.notifications.create(uid, 'DUE_SOON', message, `/tasks/${t._id}`);
        this.realtime.userRoom(uid, 'notification.created', { type: 'DUE_SOON', message });
      }
      if (tasks.length) {
        await this.model.updateMany({ _id: { $in: tasks.map((t) => t._id) } }, { $set: { dueReminderSent: true } });
      }
    } catch (e) {
      this.logger.error('Nhắc deadline bị lỗi', (e as Error)?.stack);
    }
  }
}