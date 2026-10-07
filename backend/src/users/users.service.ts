import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from './schemas/user.schema';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(@InjectModel(User.name) private readonly model: Model<UserDocument>) {}

  async create(data: Pick<User, 'email' | 'username' | 'fullName' | 'passwordHash'> & Partial<Pick<User, 'role'>>) {
    try { return await this.model.create(data); } catch (e) { throw new BadRequestException('Email hoặc username đã tồn tại'); }
  }

  async findByLogin(login: string) { return this.model.findOne({ $or: [{ email: login.toLowerCase() }, { username: login }] }).select('+passwordHash').exec(); }
  async findByEmailOrUsername(q: string) { return this.model.findOne({ $or: [{ email: q.toLowerCase() }, { username: q }] }).exec(); }
  async findPublicById(id: string) { return this.model.findById(id).select('_id email username fullName role avatarUrl').lean().exec(); }
  async getById(id: string) { const u = await this.model.findById(id).exec(); if (!u) throw new NotFoundException('Không tìm thấy người dùng'); return u; }
  async search(q: string) { const regex = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'); return this.model.find({ $or: [{ email: regex }, { username: regex }, { fullName: regex }] }).select('_id email username fullName role avatarUrl').limit(20).lean().exec(); }

  async updateProfile(id: string, dto: UpdateProfileDto) {
    try { const updated = await this.model.findByIdAndUpdate(id, dto, { new: true, runValidators: true }).select('_id email username fullName role avatarUrl').lean(); if (!updated) throw new NotFoundException('Không tìm thấy người dùng'); return updated; }
    catch { throw new BadRequestException('Không thể cập nhật thông tin. Username có thể đã tồn tại.'); }
  }

  async updateAvatar(id: string, path: string) { return this.model.findByIdAndUpdate(id, { avatarUrl: path }, { new: true }).select('_id email username fullName role avatarUrl').lean(); }
  async adminList() { return this.model.find().select('_id email username fullName role avatarUrl createdAt').sort({createdAt:-1}).lean().exec(); }
  async adminUpdateRole(id: string, role: 'admin'|'manager'|'member') { return this.model.findByIdAndUpdate(id,{role},{new:true}).select('_id email username fullName role avatarUrl').lean().exec(); }
  async adminDelete(id: string) { await this.model.findByIdAndDelete(id); return {ok:true}; }
  async sanitizeMany(ids: string[]) { const objectIds = ids.filter(Types.ObjectId.isValid).map(id => new Types.ObjectId(id)); return this.model.find({ _id: { $in: objectIds } }).select('_id email username fullName role avatarUrl').lean().exec(); }
}
