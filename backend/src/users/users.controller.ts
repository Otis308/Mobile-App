import { Controller, Get, Patch, Query, Body, UseGuards, UploadedFile, UseInterceptors, BadRequestException, Delete, Param } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'node:path';
import { randomUUID } from 'node:crypto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { AdminUserDto } from './dto/admin-user.dto';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('admin')
  adminList() { return this.users.adminList(); }

  @Patch(':id/role')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('admin')
  adminRole(@Param('id') id: string, @Body() dto: AdminUserDto) { if (!dto.role) throw new BadRequestException('Thiếu role'); return this.users.adminUpdateRole(id, dto.role); }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('admin')
  adminDelete(@Param('id') id: string) { return this.users.adminDelete(id); }

  @Get('me') me(@CurrentUser() user: any) { return user; }
  @Patch('me') update(@CurrentUser() user: any, @Body() dto: UpdateProfileDto) { return this.users.updateProfile(user._id, dto); }
  @Get('search') search(@Query('q') q = '') { if (q.trim().length < 2) throw new BadRequestException('Từ khóa cần ít nhất 2 ký tự'); return this.users.search(q.trim()); }
  @Patch('me/avatar')
  @UseInterceptors(FileInterceptor('file', { storage: diskStorage({ destination: './uploads/avatars', filename: (_req, file, cb) => cb(null, `${randomUUID()}${extname(file.originalname).toLowerCase()}`) }), limits: { fileSize: 5 * 1024 * 1024 }, fileFilter: (_req, file, cb) => cb(null, /^image\/(jpeg|png|webp)$/.test(file.mimetype)) }))
  async avatar(@CurrentUser() user: any, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException('Chỉ chấp nhận JPEG, PNG hoặc WebP dưới 5MB');
    return this.users.updateAvatar(user._id, `/uploads/avatars/${file.filename}`);
  }
}
