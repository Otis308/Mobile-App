import { NestExpressApplication } from '@nestjs/platform-express';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { join } from 'node:path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const config = app.get(ConfigService);
  app.setGlobalPrefix('api');

  const allowed = (config.get<string>('CORS_ORIGINS') ?? '')
    .split(',')
    .map((v: string) => v.trim())
    .filter(Boolean);

  app.enableCors({
    // Đã sửa 'origin: string' thành 'origin: string | undefined'
    origin: (origin: string | undefined, cb: (err: Error | null, allow?: boolean) => void) => {
      if (!origin) return cb(null, true); // Cho phép request không có Origin (như Mobile App)
      if (allowed.includes('*') || allowed.includes(origin)) return cb(null, true);
      if (/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return cb(null, true);
      return cb(null, false);
    },
    credentials: true,
  });

  app.useStaticAssets(join(process.cwd(), config.get('UPLOAD_DIR', 'uploads')), { prefix: '/uploads' });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: false }));

  const port = process.env.PORT || 3000;
  // Lắng nghe trên '0.0.0.0' để tương thích với các dịch vụ Cloud
  await app.listen(port, '0.0.0.0');
  console.log(`Application is running on port: ${port}`);
}
bootstrap();