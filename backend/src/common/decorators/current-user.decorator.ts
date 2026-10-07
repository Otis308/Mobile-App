import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface CurrentUserValue {
  _id: string;
  email: string;
  username: string;
  fullName: string;
  role: 'admin' | 'manager' | 'member';
  avatarUrl?: string;
}

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): CurrentUserValue => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
  },
);
