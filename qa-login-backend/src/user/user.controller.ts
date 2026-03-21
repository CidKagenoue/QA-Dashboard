import { Controller, Patch, Param, Body, Get } from '@nestjs/common';
import { UserService } from './user.service';
import { UpdateUserDto } from './dto/update-user.dto';

@Controller('user')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get(':id')
  async getById(@Param('id') id: string) {
    return this.userService.findById(Number(id));
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() body: UpdateUserDto) {
    return this.userService.update(Number(id), body);
  }
}
