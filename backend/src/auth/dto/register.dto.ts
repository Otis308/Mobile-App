import { IsEmail, IsOptional, IsString, Length, Matches } from 'class-validator';
export class RegisterDto {
  @IsEmail() email!: string;
  @IsString() @Length(3, 30) @Matches(/^[a-zA-Z0-9_.-]+$/) username!: string;
  @IsString() @Length(2, 80) fullName!: string;
  @IsString() @Length(8, 72) password!: string;
}
