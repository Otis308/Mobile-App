import { IsString, Length } from 'class-validator';
export class LoginDto { @IsString() @Length(3, 120) login!: string; @IsString() @Length(8, 72) password!: string; }
