import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Project, ProjectDocument } from '../projects/schemas/project.schema';
import { Task, TaskDocument } from '../tasks/schemas/task.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { UsersService } from '../users/users.service';
@Injectable()
export class DashboardService {
  constructor(@InjectModel(Project.name) private readonly projects:Model<ProjectDocument>, @InjectModel(Task.name) private readonly tasks:Model<TaskDocument>, private readonly notifications:NotificationsService, private readonly users:UsersService){}
  async summary(userId: string) {
    const uid = new Types.ObjectId(userId);
    const all = await this.projects.find({ 'members.userId': uid }).sort({ updatedAt: -1 }).lean();
    const projects = all.slice(0, 6); // chỉ hiển thị 6 dự án gần nhất

    const start = new Date(); start.setHours(0, 0, 0, 0);
    const end = new Date(start); end.setDate(end.getDate() + 1);
    const weekAgo = new Date(Date.now() - 7 * 24 * 3600 * 1000);

    const today = await this.tasks.find({
      projectId: { $in: all.map((p: any) => p._id) },
      assigneeId: uid,
      dueDate: { $lt: end },          // hôm nay + quá hạn
      status: { $ne: 'done' },
    }).sort({ dueDate: 1 }).lean();

    const completedThisWeek = await this.tasks.countDocuments({
      assigneeId: uid, status: 'done', completedAt: { $gte: weekAgo },
    });
    const assigned = await this.tasks.countDocuments({ assigneeId: uid });
    const done = await this.tasks.countDocuments({ assigneeId: uid, status: 'done' });
    const unread = await this.notifications.unread(userId);

    return {
      projects, totalProjects: all.length, todayTasks: today, unreadNotifications: unread,
      performance: {
        completedThisWeek, assignedTotal: assigned,
        completionRate: assigned ? Math.round((done / assigned) * 100) : 0,
      },
    };
  }
}
