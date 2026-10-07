import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { UsersModule } from '../users/users.module';
import { MailerModule } from '@nestjs-modules/mailer';
@Module({ 
    imports: [
        UsersModule,
        MailerModule.forRoot({
        transport: {
            host: process.env.SMTP_HOST,
            port: Number(process.env.SMTP_PORT) || 587,
            secure: false, 
            auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS, 
            },
        },
        }),
    ], 
    controllers: [AuthController], 
    providers: [AuthService],
})
export class AuthModule {}
