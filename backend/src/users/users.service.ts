import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from './schemas/user.schema';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
@Injectable()
export class UsersService {
  // Khởi tạo kết nối với bảng (collection) User trong MongoDB
  constructor(@InjectModel(User.name) private readonly model: Model<UserDocument>) {}

  // 1. TẠO TÀI KHOẢN MỚI (Lưu dữ liệu Đăng ký vào MongoDB)
  async create(data: Pick<User, 'email' | 'username' | 'fullName' | 'passwordHash' | 'phone' | 'dob' | 'gender'> & Partial<Pick<User, 'role'>>) {
    try { 
      return await this.model.create(data); 
    } catch (e) { 
      throw new BadRequestException('Email hoặc username đã tồn tại'); 
    }
  }

  // 2. TÌM TÀI KHOẢN ĐỂ ĐĂNG NHẬP 
  // (Tìm bằng email hoặc username, và lấy luôn cả mật khẩu đã mã hóa để so sánh)
  async findByLogin(login: string) { 
    return this.model.findOne({ $or: [{ email: login.toLowerCase() }, { username: login }] }).select('+passwordHash').exec(); 
  }

  // 3. KIỂM TRA TỒN TẠI TÀI KHOẢN
  // (Dùng để check xem email/username đã ai đăng ký chưa, hoặc tìm user khi Quên mật khẩu)
  async findByEmailOrUsername(q: string) { 
    return this.model.findOne({ $or: [{ email: q.toLowerCase() }, { username: q }] }).exec(); 
  }

  // 4. LẤY THÔNG TIN CÔNG KHAI CỦA 1 NGƯỜI DÙNG
  // (Trả về thông tin cơ bản qua ID, bảo mật không trả về mật khẩu hay OTP)
  async findPublicById(id: string) { 
    return this.model.findById(id).select('_id email username fullName role avatarUrl').lean().exec(); 
  }

  // 5. LẤY CHI TIẾT NGƯỜI DÙNG QUA ID
  // (Nếu không tìm thấy sẽ ném ra lỗi 404)
  async getById(id: string) { 
    const u = await this.model.findById(id).exec(); 
    if (!u) throw new NotFoundException('Không tìm thấy người dùng'); 
    return u; 
  }

  // 6. TÌM KIẾM NGƯỜI DÙNG (SEARCH)
  // (Tìm kiếm gần đúng (like) theo email, username hoặc họ tên)
  async search(q: string) { 
    const regex = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'); 
    return this.model.find({ $or: [{ email: regex }, { username: regex }, { fullName: regex }] }).select('_id email username fullName role avatarUrl').limit(20).lean().exec(); 
  }

  // 7. CẬP NHẬT HỒ SƠ CÁ NHÂN
  // (Cho phép người dùng sửa thông tin của chính mình)
  async updateProfile(id: string, dto: UpdateProfileDto) {
    let updated;
    try {
      updated = await this.model
        .findByIdAndUpdate(id, dto, { new: true, runValidators: true })
        .select('_id email username fullName role avatarUrl').lean();
    } catch (e: any) {
      if (e?.code === 11000) throw new BadRequestException('Username đã tồn tại');
      throw new BadRequestException('Không thể cập nhật thông tin');
    }
    if (!updated) throw new NotFoundException('Không tìm thấy người dùng');
    return updated;
  }

  // 8. CẬP NHẬT ẢNH ĐẠI DIỆN
  async updateAvatar(id: string, path: string) { 
    return this.model.findByIdAndUpdate(id, { avatarUrl: path }, { new: true }).select('_id email username fullName role avatarUrl').lean(); 
  }

  // 9. [DÀNH CHO ADMIN] LẤY DANH SÁCH TẤT CẢ NGƯỜI DÙNG
  // (Sắp xếp theo thời gian tạo mới nhất lên đầu)
  async adminList() { 
    return this.model.find().select('_id email username fullName role avatarUrl createdAt').sort({createdAt:-1}).lean().exec(); 
  }

  // 10. [DÀNH CHO ADMIN] PHÂN QUYỀN NGƯỜI DÙNG
  // (Thay đổi chức vụ thành admin, manager, hoặc member)
  async adminUpdateRole(id: string, role: 'admin'|'manager'|'member') { 
    return this.model.findByIdAndUpdate(id,{role},{new:true}).select('_id email username fullName role avatarUrl').lean().exec(); 
  }

  // 11. [DÀNH CHO ADMIN] XÓA TÀI KHOẢN
  // (Xóa vĩnh viễn user khỏi database)
  async adminDelete(id: string) { 
    await this.model.findByIdAndDelete(id); 
    return {ok:true}; 
  }

  // 12. LỌC DANH SÁCH ID AN TOÀN
  // (Biến mảng ID text thành ObjectId của MongoDB để truy vấn nhiều user cùng lúc)
  async sanitizeMany(ids: string[]) { 
    const objectIds = ids.filter(Types.ObjectId.isValid).map(id => new Types.ObjectId(id)); 
    return this.model.find({ _id: { $in: objectIds } }).select('_id email username fullName role avatarUrl').lean().exec(); 
  }

  // 13. [QUÊN MẬT KHẨU] LƯU MÃ OTP 
  // (Lưu mã số OTP và thời hạn 15 phút vào tài khoản người dùng)
  async saveOtp(userId: string, otp: string, expires: Date) {
    return this.model.findByIdAndUpdate(userId, {
      resetPasswordOtp: otp,
      resetPasswordExpires: expires,
    });
  }
  async incOtpAttempts(userId: string) {
    await this.model.findByIdAndUpdate(userId, { $inc: { resetOtpAttempts: 1 } });
  }

  // 14. [QUÊN MẬT KHẨU] ĐỔI MẬT KHẨU MỚI
  // (Lưu mật khẩu mới và xóa trắng mã OTP để không bị dùng lại)
  async updatePasswordAndClearOtp(userId: string, passwordHash: string) {
    return this.model.findByIdAndUpdate(userId, {
      resetOtpAttempts: 0,
      passwordHash: passwordHash,
      resetPasswordOtp: null,
      resetPasswordExpires: null,
      lastPasswordReset: new Date(), 
    });
  }
}