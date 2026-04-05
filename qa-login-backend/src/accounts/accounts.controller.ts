import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { AdminGuard } from './admin.guard';
import { AccountsService } from './accounts.service';
import {
  CreateAccountDto,
  UpdateAccountAccessDto,
} from './dto/account-management.dto';

@Controller('accounts')
@UseGuards(AdminGuard)
export class AccountsController {
  constructor(private readonly accountsService: AccountsService) {}

  @Get()
  async listAccounts(@Query('search') search?: string) {
    return this.accountsService.listAccounts(search);
  }

  @Post()
  async createAccount(@Body() createAccountDto: CreateAccountDto) {
    return this.accountsService.createAccount(createAccountDto);
  }

  @Patch(':id/access')
  async updateAccountAccess(
    @Param('id', ParseIntPipe) accountId: number,
    @Body() updateAccountAccessDto: UpdateAccountAccessDto,
  ) {
    return this.accountsService.updateAccountAccess(accountId, updateAccountAccessDto);
  }

  @Delete(':id')
  async deleteAccount(
    @Param('id', ParseIntPipe) accountId: number,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.accountsService.deleteAccount(accountId, this.readActorId(req));
  }

  private readActorId(req: AuthenticatedRequest) {
    if (!req.user || typeof req.user === 'string') {
      throw new UnauthorizedException('Invalid token payload');
    }

    const actorId = typeof req.user.sub === 'number' ? req.user.sub : Number(req.user.sub);
    if (!Number.isInteger(actorId) || actorId <= 0) {
      throw new UnauthorizedException('Invalid token subject');
    }

    return actorId;
  }
}
