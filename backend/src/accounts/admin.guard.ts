import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { UserService } from '../user/user.service';

@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private readonly userService: UserService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();

    if (!request.user || typeof request.user === 'string') {
      throw new UnauthorizedException('Invalid token payload');
    }

    const userId = typeof request.user.sub === 'number'
      ? request.user.sub
      : Number(request.user.sub);

    if (!Number.isInteger(userId) || userId <= 0) {
      throw new UnauthorizedException('Invalid token subject');
    }

    const user = await this.userService.findById(userId);
    if (!user) {
      throw new UnauthorizedException('User does not exist');
    }

    if (!user.isAdmin) {
      throw new ForbiddenException('Admin access is required');
    }

    return true;
  }
}
