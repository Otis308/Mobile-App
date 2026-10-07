import { Controller, Get, UseGuards } from '@nestjs/common';
import { DashboardService } from './dashboard.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
@Controller('dashboard') @UseGuards(JwtAuthGuard) export class DashboardController {constructor(private readonly dashboard:DashboardService){} @Get() summary(@CurrentUser()u:any){return this.dashboard.summary(u._id)}}
