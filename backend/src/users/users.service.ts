import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from './schemas/user.schema';
import { UpdateProfileDto } from './dto/update-profile.dto';

interface CachedPublicUser {
  data: any;
  expiresAt: number;
}

@Injectable()
export class UsersService {
  private static readonly CACHE_TTL_MS = 30_000; // Cache 30 giây giảm tải DB cho JwtAuthGuard
  private readonly publicUserCache = new Map<string, CachedPublicUser>();

  constructor(@InjectModel(User.name) private readonly model: Model<UserDocument>) {}

  invalidateCache(userId: string) {
    this.publicUserCache.delete(userId);
  }

  async create(
    data: Pick<User, 'email' | 'username' | 'fullName' | 'passwordHash' | 'phone' | 'dob' | 'gender'> &
      Partial<Pick<User, 'role'>>,
  ) {
    try {
      return await this.model.create(data);
    } catch {
      throw new BadRequestException('Email hoặc username đã tồn tại');
    }
  }

  async findByLogin(login: string) {
    return this.model
      .findOne({ $or: [{ email: login.toLowerCase() }, { username: login }] })
      .select('+passwordHash')
      .exec();
  }

  async findByEmailOrUsername(q: string) {
    return this.model
      .findOne({ $or: [{ email: q.toLowerCase() }, { username: q }] })
      .select('+resetPasswordOtp +resetPasswordExpires +resetOtpAttempts +passwordHash')
      .exec();
  }

  async findWithPasswordById(id: string) {
    return this.model.findById(id).select('+passwordHash').exec();
  }

  async findPublicById(id: string) {
    const now = Date.now();
    const cached = this.publicUserCache.get(id);
    if (cached && cached.expiresAt > now) {
      return cached.data;
    }

    const user = await this.model
      .findById(id)
      .select('_id email username fullName role avatarUrl')
      .lean()
      .exec();

    if (user) {
      this.publicUserCache.set(id, {
        data: user,
        expiresAt: now + UsersService.CACHE_TTL_MS,
      });
    } else {
      this.publicUserCache.delete(id);
    }

    return user;
  }

  async getById(id: string) {
    const u = await this.model.findById(id).exec();
    if (!u) throw new NotFoundException('Không tìm thấy người dùng');
    return u;
  }

  async search(q: string) {
    const regex = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
    return this.model
      .find({ $or: [{ email: regex }, { username: regex }, { fullName: regex }] })
      .select('_id email username fullName role avatarUrl')
      .limit(20)
      .lean()
      .exec();
  }

  async updateProfile(id: string, dto: UpdateProfileDto) {
    let updated;
    try {
      updated = await this.model
        .findByIdAndUpdate(id, dto, { new: true, runValidators: true })
        .select('_id email username fullName role avatarUrl')
        .lean();
    } catch (e: any) {
      if (e?.code === 11000) throw new BadRequestException('Username đã tồn tại');
      throw new BadRequestException('Không thể cập nhật thông tin');
    }
    if (!updated) throw new NotFoundException('Không tìm thấy người dùng');
    this.invalidateCache(id);
    return updated;
  }

  async updateAvatar(id: string, path: string) {
    const updated = await this.model
      .findByIdAndUpdate(id, { avatarUrl: path }, { new: true })
      .select('_id email username fullName role avatarUrl')
      .lean();
    this.invalidateCache(id);
    return updated;
  }

  async adminList() {
    return this.model
      .find()
      .select('_id email username fullName role avatarUrl createdAt')
      .sort({ createdAt: -1 })
      .lean()
      .exec();
  }

  async adminUpdateRole(id: string, role: 'admin' | 'manager' | 'member', actorId?: string) {
    if (actorId && actorId === id && role !== 'admin') {
      throw new BadRequestException('Admin không thể tự hạ quyền của chính mình');
    }
    const updated = await this.model
      .findByIdAndUpdate(id, { role }, { new: true })
      .select('_id email username fullName role avatarUrl')
      .lean()
      .exec();
    this.invalidateCache(id);
    return updated;
  }

  async adminDelete(id: string, actorId?: string) {
    if (actorId && actorId === id) {
      throw new BadRequestException('Admin không thể tự xóa tài khoản của chính mình');
    }
    await this.model.findByIdAndDelete(id);
    this.invalidateCache(id);
    return { ok: true };
  }

  async sanitizeMany(ids: string[]) {
    const objectIds = ids.filter(Types.ObjectId.isValid).map((id) => new Types.ObjectId(id));
    return this.model
      .find({ _id: { $in: objectIds } })
      .select('_id email username fullName role avatarUrl')
      .lean()
      .exec();
  }

  async saveOtp(userId: string, otpHash: string, expires: Date) {
    return this.model.findByIdAndUpdate(userId, {
      resetPasswordOtp: otpHash,
      resetPasswordExpires: expires,
      resetOtpAttempts: 0,
    });
  }

  async incOtpAttempts(userId: string) {
    await this.model.findByIdAndUpdate(userId, { $inc: { resetOtpAttempts: 1 } });
  }

  async updatePasswordAndClearOtp(userId: string, passwordHash: string) {
    this.invalidateCache(userId);
    return this.model.findByIdAndUpdate(userId, {
      resetOtpAttempts: 0,
      passwordHash,
      resetPasswordOtp: null,
      resetPasswordExpires: null,
      lastPasswordReset: new Date(),
    });
  }
}