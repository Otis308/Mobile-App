// File: backend/src/auth/auth.service.ts
import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { createHash, randomInt } from 'node:crypto';
import { UsersService } from '../users/users.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { MailerService } from '@nestjs-modules/mailer';

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly mailer: MailerService,
  ) {}

  private token(user: any) {
    return this.jwt.sign({
      sub: user._id.toString(),
      email: user.email,
      role: user.role,
    });
  }

  private hashOtp(otp: string): string {
    return createHash('sha256').update(otp).digest('hex');
  }

  async register(dto: RegisterDto) {
    const existing =
      (await this.users.findByEmailOrUsername(dto.email)) ||
      (await this.users.findByEmailOrUsername(dto.username));
    if (existing) {
      throw new ConflictException('Tên đăng nhập hoặc Email đã được sử dụng');
    }

    const user = await this.users.create({
      email: dto.email.toLowerCase(),
      username: dto.username.trim(),
      fullName: dto.fullName.trim(),
      passwordHash: await bcrypt.hash(dto.password, 12),
      phone: dto.phone.trim(),
      dob: dto.dob.trim(),
      gender: dto.gender.trim(),
      role: 'member',
    });

    return {
      accessToken: this.token(user),
      user: await this.users.findPublicById(user._id.toString()),
    };
  }

  async login(dto: LoginDto) {
    const user = await this.users.findByLogin(dto.login.trim());
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Sai tài khoản hoặc mật khẩu');
    }
    return {
      accessToken: this.token(user),
      user: await this.users.findPublicById(user._id.toString()),
    };
  }

  private async checkOtp(user: any, otp: string) {
    if (
      !user.resetPasswordOtp ||
      !user.resetPasswordExpires ||
      new Date() > user.resetPasswordExpires
    ) {
      throw new BadRequestException('Mã OTP đã hết hạn');
    }
    if ((user.resetOtpAttempts ?? 0) >= 5) {
      throw new BadRequestException('Nhập sai quá nhiều lần, vui lòng yêu cầu mã mới');
    }
    const hashedInput = this.hashOtp(otp);
    if (user.resetPasswordOtp !== hashedInput && user.resetPasswordOtp !== otp) {
      await this.users.incOtpAttempts(user._id.toString());
      throw new BadRequestException('Mã OTP không chính xác');
    }
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    const user = await this.users.findByEmailOrUsername(dto.email.trim());
    if (!user) {
      return { message: 'Nếu email tồn tại, mã OTP đã được gửi' };
    }

    if (user.lastPasswordReset) {
      const threeDaysAgo = new Date();
      threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);
      if (user.lastPasswordReset > threeDaysAgo) {
        throw new BadRequestException(
          'Bạn chỉ được phép khôi phục mật khẩu 3 ngày 1 lần. Vui lòng thử lại sau!',
        );
      }
    }

    const otp = randomInt(100000, 1000000).toString();
    const expires = new Date(Date.now() + 15 * 60 * 1000);
    await this.users.saveOtp(user._id.toString(), this.hashOtp(otp), expires);

    await this.mailer.sendMail({
      to: user.email,
      subject: 'Mã xác nhận khôi phục mật khẩu',
      text: `Chào bạn,\n\nMã OTP của bạn là: ${otp}\n\nMã này sẽ hết hạn sau 15 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai.`,
    });

    return { message: 'Mã OTP đã được gửi đến email của bạn' };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const user = await this.users.findByEmailOrUsername(dto.email.trim());
    if (!user) throw new BadRequestException('Mã OTP không chính xác');
    await this.checkOtp(user, dto.otp.trim());
    return { message: 'Xác thực OTP thành công' };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const user = await this.users.findByEmailOrUsername(dto.email.trim());
    if (!user) throw new BadRequestException('Mã OTP không chính xác');
    await this.checkOtp(user, dto.otp.trim());

    const passwordHash = await bcrypt.hash(dto.newPassword, 12);
    await this.users.updatePasswordAndClearOtp(user._id.toString(), passwordHash);

    return { message: 'Đổi mật khẩu thành công' };
  }

  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    if (!currentPassword || !newPassword || newPassword.length < 8) {
      throw new BadRequestException('Mật khẩu mới phải có ít nhất 8 ký tự');
    }
    const user = await this.users.findWithPasswordById(userId);
    if (!user || !(await bcrypt.compare(currentPassword, user.passwordHash))) {
      throw new UnauthorizedException('Mật khẩu hiện tại không chính xác');
    }
    const passwordHash = await bcrypt.hash(newPassword, 12);
    await this.users.updatePasswordAndClearOtp(userId, passwordHash);
    return { message: 'Đổi mật khẩu thành công' };
  }
}