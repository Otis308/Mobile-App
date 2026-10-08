import { Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  list(@CurrentUser() user: any) {
    return this.notificationsService.list(user._id);
  }

  @Get('unread-count')
  async unread(@CurrentUser() user: any) {
    const count = await this.notificationsService.unread(user._id);
    return { count };
  }

  @Patch('read-all')
  readAll(@CurrentUser() user: any) {
    return this.notificationsService.markAllRead(user._id);
  }

  @Patch(':id/read')
  read(@Param('id') id: string, @CurrentUser() user: any) {
    return this.notificationsService.markRead(id, user._id);
  }
}