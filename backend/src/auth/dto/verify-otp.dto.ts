import { IsEmail, IsNotEmpty, IsString, Length } from 'class-validator';

export class VerifyOtpDto {
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @IsString()
  @Length(6, 6, { message: 'Mã OTP phải gồm đúng 6 ký tự' })
  @IsNotEmpty()
  otp: string;
}