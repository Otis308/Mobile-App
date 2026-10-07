import { BadRequestException, ConflictException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { MailerService } from '@nestjs-modules/mailer';
import * as otpGenerator from 'otp-generator';

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersService, 
    private readonly jwt: JwtService,
    private readonly mailer: MailerService // Inject MailerService để gửi email
  ) {}
  
  private token(user: any) { return this.jwt.sign({ sub: user._id.toString(), email: user.email, role: user.role }); }

  async register(dto: RegisterDto) {
    const existing = await this.users.findByEmailOrUsername(dto.email) || await this.users.findByEmailOrUsername(dto.username);
    if (existing) throw new ConflictException('Tên đăng nhập hoặc Email đã được sử dụng');
    
    const user = await this.users.create({ 
      email: dto.email.toLowerCase(), 
      username: dto.username, 
      fullName: dto.fullName, 
      passwordHash: await bcrypt.hash(dto.password, 12),
      phone: dto.phone,
      dob: dto.dob,
      gender: dto.gender,
      role: 'member' 
    });
    
    return { accessToken: this.token(user), user: await this.users.findPublicById(user._id.toString()) };
  }

  async login(dto: LoginDto) {
    const user = await this.users.findByLogin(dto.login);
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) throw new UnauthorizedException('Sai tài khoản hoặc mật khẩu');
    return { accessToken: this.token(user), user: await this.users.findPublicById(user._id.toString()) };
  }

  // --- LOGIC QUÊN MẬT KHẨU ---

  async forgotPassword(dto: ForgotPasswordDto) {
    const user = await this.users.findByEmailOrUsername(dto.email);
    if (!user) throw new NotFoundException('Không tìm thấy tài khoản với email này');

    // KIỂM TRA GIỚI HẠN 3 NGÀY
    if (user.lastPasswordReset) {
      const threeDaysAgo = new Date();
      threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);
      if (user.lastPasswordReset > threeDaysAgo) {
        throw new BadRequestException('Bạn chỉ được phép khôi phục mật khẩu 3 ngày 1 lần. Vui lòng thử lại sau!');
      }
    }

    const otp = otpGenerator.generate(6, { upperCaseAlphabets: false, specialChars: false, lowerCaseAlphabets: false });
    const expires = new Date();
    expires.setMinutes(expires.getMinutes() + 15);
    await this.users.saveOtp(user._id.toString(), otp, expires);

    // Gửi Email
    await this.mailer.sendMail({
      to: user.email,
      subject: 'Mã xác nhận khôi phục mật khẩu',
      text: `Chào bạn,\n\nMã OTP của bạn là: ${otp}\n\nMã này sẽ hết hạn sau 15 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai.`,
    });

    return { message: 'Mã OTP đã được gửi đến email của bạn' };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const user = await this.users.findByEmailOrUsername(dto.email);
    if (!user) throw new NotFoundException('Không tìm thấy người dùng');
    
    // Kiểm tra OTP và thời gian hết hạn
    if (user.resetPasswordOtp !== dto.otp) throw new BadRequestException('Mã OTP không chính xác');
    if (new Date() > new Date(user.resetPasswordExpires!)) throw new BadRequestException('Mã OTP đã hết hạn');

    return { message: 'Xác thực OTP thành công' };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const user = await this.users.findByEmailOrUsername(dto.email);
    if (!user) throw new NotFoundException('Không tìm thấy người dùng');
    
    // Kiểm tra lại lần cuối trước khi đổi pass
    if (user.resetPasswordOtp !== dto.otp || new Date() > new Date(user.resetPasswordExpires!)) {
      throw new BadRequestException('Mã OTP không hợp lệ hoặc đã hết hạn');
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, 12);
    
    // Lưu mật khẩu mới và xóa OTP khỏi DB
    await this.users.updatePasswordAndClearOtp(user._id.toString(), passwordHash);

    return { message: 'Đổi mật khẩu thành công' };
  }
}