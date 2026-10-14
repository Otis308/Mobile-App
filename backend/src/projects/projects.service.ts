import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Project, ProjectDocument } from './schemas/project.schema';
import { CreateProjectDto } from './dto/create-project.dto';
import { UpdateProjectDto } from './dto/update-project.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { UsersService } from '../users/users.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { Task, TaskDocument } from '../tasks/schemas/task.schema';
import { Comment, CommentDocument } from '../comments/schemas/comment.schema';
import { UpdateMemberRoleDto } from './dto/update-member-role.dto';

@Injectable()
export class ProjectsService {
  constructor(
    @InjectModel(Project.name) private readonly model: Model<ProjectDocument>,
    private readonly users: UsersService,
    private readonly realtime: RealtimeGateway,
    private readonly notifications: NotificationsService,
    @InjectModel(Task.name) private readonly taskModel: Model<TaskDocument>,
    @InjectModel(Comment.name) private readonly commentModel: Model<CommentDocument>,
  ) {}

  async listForUser(userId: string) {
    return this.model
      .find({ 'members.userId': new Types.ObjectId(userId) })
      .sort({ updatedAt: -1 })
      .lean()
      .exec();
  }

  async get(id: string) {
    if (!Types.ObjectId.isValid(id)) throw new BadRequestException('ID dự án không hợp lệ');
    const p = await this.model.findById(id).lean().exec();
    if (!p) throw new NotFoundException('Không tìm thấy dự án');
    return p;
  }

  async member(id: string, userId: string) {
    const p = await this.get(id);
    const member = p.members.find((m: any) => m.userId.toString() === userId);
    if (!member) throw new ForbiddenException('Bạn không thuộc dự án này');
    return { project: p, member };
  }

  async canManage(id: string, userId: string) {
    const { project, member } = await this.member(id, userId);
    return (
      project.ownerId.toString() === userId ||
      member.role === 'owner' ||
      member.role === 'manager'
    );
  }

  async create(userId: string, dto: CreateProjectDto) {
    const p = await this.model.create({
      ...dto,
      ownerId: new Types.ObjectId(userId),
      members: [{ userId: new Types.ObjectId(userId), role: 'owner', joinedAt: new Date() }],
    });
    const obj = p.toObject();
    await this.realtime.addUserToProject(userId, obj._id.toString());
    return obj;
  }

  async update(id: string, userId: string, dto: UpdateProjectDto) {
    if (!(await this.canManage(id, userId))) {
      throw new ForbiddenException('Chỉ owner/manager mới được sửa dự án');
    }

    const p = await this.model
      .findByIdAndUpdate(id, dto, { new: true, runValidators: true })
      .lean();
    if (!p) throw new NotFoundException('Không tìm thấy dự án');

    this.realtime.projectRoom(id, 'project.updated', p);
    return p;
  }

  async addMember(id: string, actorId: string, dto: AddMemberDto) {
    const { project, member } = await this.member(id, actorId);
    const isOwner = project.ownerId.toString() === actorId || member.role === 'owner';
    const isManager = member.role === 'manager';

    if (!isOwner && !isManager) {
      throw new ForbiddenException('Bạn không có quyền thêm thành viên');
    }
    if (!isOwner && dto.role === 'manager') {
      throw new ForbiddenException('Chỉ Chủ dự án mới được thêm thành viên với quyền Quản lý');
    }

    const user = await this.users.getById(dto.userId);
    const targetUserId = user._id.toString();
    const uid = new Types.ObjectId(targetUserId);

    const updated = await this.model
      .findOneAndUpdate(
        { _id: new Types.ObjectId(id), 'members.userId': { $ne: uid } },
        {
          $push: {
            members: { userId: uid, role: dto.role, joinedAt: new Date() },
          },
        },
        { new: true },
      )
      .lean();

    if (!updated) {
      throw new BadRequestException('Người dùng đã ở trong dự án');
    }

    const msg = `Bạn được thêm vào dự án ${updated.name}`;
    await this.notifications.create(targetUserId, 'MEMBER_ADDED', msg, `/projects/${id}`);

    await this.realtime.addUserToProject(targetUserId, id);
    this.realtime.projectRoom(id, 'project.memberAdded', updated);
    this.realtime.userRoom(targetUserId, 'project.memberAdded', updated);
    this.realtime.userRoom(targetUserId, 'notification.created', {
      type: 'MEMBER_ADDED',
      message: msg,
    });
    return updated;
  }

  async updateMemberRole(id: string, actorId: string, userId: string, dto: UpdateMemberRoleDto) {
    const { project } = await this.member(id, actorId);
    if (project.ownerId.toString() !== actorId) {
      throw new ForbiddenException('Chỉ chủ dự án mới được đổi quyền');
    }
    if (project.ownerId.toString() === userId) {
      throw new BadRequestException('Không thể đổi quyền của chủ dự án');
    }

    const p = await this.model
      .findOneAndUpdate(
        { _id: new Types.ObjectId(id), 'members.userId': new Types.ObjectId(userId) },
        { $set: { 'members.$.role': dto.role } },
        { new: true },
      )
      .lean();

    if (!p) throw new NotFoundException('Thành viên không thuộc dự án');

    const message = `Quyền của bạn trong dự án ${p.name} đã đổi thành ${
      dto.role === 'manager' ? 'Quản lý' : 'Thành viên'
    }`;
    await this.notifications.create(userId, 'ROLE_CHANGED', message, `/projects/${id}`);
    this.realtime.projectRoom(id, 'project.memberUpdated', p);
    this.realtime.userRoom(userId, 'project.memberUpdated', p);
    this.realtime.userRoom(userId, 'notification.created', { type: 'ROLE_CHANGED', message });
    return p;
  }

  async removeMember(id: string, actorId: string, userId: string) {
    const { project, member } = await this.member(id, actorId);
    const isSelf = actorId === userId;

    if (project.ownerId.toString() === userId) {
      throw new BadRequestException('Không thể xóa chủ dự án');
    }

    const target = project.members.find((m: any) => m.userId.toString() === userId);
    if (!target) throw new NotFoundException('Thành viên không thuộc dự án');

    if (!isSelf) {
      const actorIsOwner = project.ownerId.toString() === actorId;
      const managerRemovesMember = member.role === 'manager' && target.role === 'member';
      if (!actorIsOwner && !managerRemovesMember) {
        throw new ForbiddenException('Bạn không có quyền xóa thành viên này');
      }
    }

    const pid = new Types.ObjectId(id);
    const uid = new Types.ObjectId(userId);

    await this.model.updateOne({ _id: pid }, { $pull: { members: { userId: uid } } } as any);
    await this.taskModel.updateMany(
      { projectId: pid, assigneeId: uid },
      { $set: { assigneeId: null } } as any,
    );

    const result = await this.model.findById(id).lean();

    if (!isSelf) {
      const message = `Bạn đã bị xóa khỏi dự án ${project.name}`;
      await this.notifications.create(userId, 'MEMBER_REMOVED', message);
      this.realtime.userRoom(userId, 'notification.created', {
        type: 'MEMBER_REMOVED',
        message,
      });
    }

    this.realtime.projectRoom(id, 'project.memberRemoved', { projectId: id, userId });
    this.realtime.userRoom(userId, 'project.memberRemoved', { projectId: id, userId });
    await this.realtime.removeUserFromProject(userId, id);
    return result;
  }

  async removeProject(id: string, userId: string) {
    const { project } = await this.member(id, userId);
    if (project.ownerId.toString() !== userId) {
      throw new ForbiddenException('Chỉ chủ dự án mới được xóa dự án');
    }

    const pid = new Types.ObjectId(id);
    const taskIds = await this.taskModel.distinct('_id', { projectId: pid });

    await this.commentModel.deleteMany({ taskId: { $in: taskIds } });
    await this.taskModel.deleteMany({ projectId: pid });
    await this.model.findByIdAndDelete(id);

    this.realtime.projectRoom(id, 'project.deleted', { projectId: id });
    return { ok: true };
  }
}