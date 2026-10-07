import { Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
@Controller('notifications') @UseGuards(JwtAuthGuard)
export class NotificationsController {constructor(private readonly notifications:NotificationsService){} @Get() list(@CurrentUser()u:any){return this.notifications.list(u._id)} @Get('unread-count') unread(@CurrentUser()u:any){return this.notifications.unread(u._id).then(count=>({count}))} @Patch(':id/read') read(@Param('id')id:string,@CurrentUser()u:any){return this.notifications.markRead(id,u._id)}}
