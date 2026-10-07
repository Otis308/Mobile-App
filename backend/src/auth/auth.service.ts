import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(private readonly users: UsersService, private readonly jwt: JwtService) {}
  private token(user: any) { return this.jwt.sign({ sub: user._id.toString(), email: user.email, role: user.role }); }

  async register(dto: RegisterDto) {
    const existing = await this.users.findByEmailOrUsername(dto.email) || await this.users.findByEmailOrUsername(dto.username);
    if (existing) throw new ConflictException('Email hoặc username đã được sử dụng');
    const user = await this.users.create({ email: dto.email.toLowerCase(), username: dto.username, fullName: dto.fullName, passwordHash: await bcrypt.hash(dto.password, 12), role: 'member' });
    return { accessToken: this.token(user), user: await this.users.findPublicById(user._id.toString()) };
  }

  async login(dto: LoginDto) {
    const user = await this.users.findByLogin(dto.login);
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) throw new UnauthorizedException('Sai tài khoản hoặc mật khẩu');
    return { accessToken: this.token(user), user: await this.users.findPublicById(user._id.toString()) };
  }
}
