import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @IsEmail({}, { message: 'Email không đúng định dạng' })
  @IsNotEmpty({ message: 'Email không được để trống' })
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'Username không được để trống' })
  @MinLength(5, { message: 'Username phải lớn hơn 4 ký tự' })
  username: string;

  @IsString()
  @IsNotEmpty({ message: 'Họ và tên không được để trống' })
  fullName: string;

  @IsString()
  @IsNotEmpty({ message: 'Mật khẩu không được để trống' })
  @MinLength(8, { message: 'Mật khẩu phải từ 8 ký tự' })
  password: string;

  @IsString()
  @IsNotEmpty({ message: 'Số điện thoại không được để trống' })
  phone: string;

  @IsString()
  @IsNotEmpty({ message: 'Ngày sinh không được để trống' })
  dob: string;

  @IsString()
  @IsNotEmpty({ message: 'Giới tính không được để trống' })
  gender: string;
}