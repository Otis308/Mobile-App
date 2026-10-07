import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { JwtModule } from '@nestjs/jwt';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ProjectsModule } from './projects/projects.module';
import { TasksModule } from './tasks/tasks.module';
import { CommentsModule } from './comments/comments.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { NotificationsModule } from './notifications/notifications.module';
import { RealtimeModule } from './realtime/realtime.module';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    MongooseModule.forRootAsync({ useFactory: (config: ConfigService) => ({ uri: config.get<string>('MONGODB_URI') }), inject: [ConfigService] }),
    JwtModule.registerAsync({ global: true, useFactory: (config: ConfigService) => ({ secret: config.get<string>('JWT_SECRET'), signOptions: { expiresIn: config.get<string>('JWT_EXPIRES_IN', '7d') as any } }), inject: [ConfigService] }),
    AuthModule,
    UsersModule,
    ProjectsModule,
    TasksModule,
    CommentsModule,
    DashboardModule,
    NotificationsModule,
    RealtimeModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
