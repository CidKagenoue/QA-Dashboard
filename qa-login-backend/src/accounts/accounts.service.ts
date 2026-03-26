import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateAccountDto,
  UpdateAccountAccessDto,
} from './dto/account-management.dto';
import { ManagedAccount, UserService } from '../user/user.service';

type AccountAccessResponse = {
  basis: boolean;
  whsTours: boolean;
  ova: boolean;
  japGpp: boolean;
  maintenanceInspections: boolean;
};

type ManagedAccountResponse = {
  id: number;
  email: string;
  name: string | null;
  departments: { id: number; name: string }[];
  isAdmin: boolean;
  access: AccountAccessResponse;
  hasAnyAccess: boolean;
};

@Injectable()
export class AccountsService {
  constructor(
    private readonly userService: UserService,
    private readonly prisma: PrismaService,
  ) {}

  async listAccounts(search?: string) {
    const accounts = await this.userService.listManagedAccounts(search?.trim() || undefined);

    return {
      accounts: accounts.map((account) => this.serializeAccount(account)),
    };
  }

  async createAccount(createAccountDto: CreateAccountDto) {
    const email = this.normalizeEmail(createAccountDto.email);
    const password = this.normalizePassword(createAccountDto.password);
    const name = this.normalizeName(createAccountDto.name);
    const isAdmin = this.readBoolean(createAccountDto, 'isAdmin');
    const departmentIds = this.normalizeDepartmentIds(
      createAccountDto.departmentIds,
    );

    const existingUser = await this.userService.findByEmail(email);
    if (existingUser) {
      throw new ConflictException('A user with that email already exists');
    }

    await this.assertDepartmentsExist(departmentIds);

    const hashedPassword = await bcrypt.hash(password, 12);
    const account = await this.userService.createManagedAccount({
      email,
      password: hashedPassword,
      name,
      isAdmin,
      basisAccess: this.readBoolean(createAccountDto, 'basisAccess'),
      whsToursAccess: this.readBoolean(createAccountDto, 'whsToursAccess'),
      ovaAccess: this.readBoolean(createAccountDto, 'ovaAccess'),
      japGppAccess: this.readBoolean(createAccountDto, 'japGppAccess'),
      maintenanceInspectionsAccess: this.readBoolean(
        createAccountDto,
        'maintenanceInspectionsAccess',
      ),
      departments: {
        create: departmentIds.map((departmentId) => ({ departmentId })),
      },
    });

    return {
      account: this.serializeAccount(account),
    };
  }

  async updateAccountAccess(
    accountId: number,
    updateAccountAccessDto: UpdateAccountAccessDto,
  ) {
    const existingAccount = await this.userService.findById(accountId);
    if (!existingAccount) {
      throw new NotFoundException('Account not found');
    }

    const updateData = this.buildAccessUpdate(updateAccountAccessDto);
    if (Object.keys(updateData).length === 0) {
      throw new BadRequestException('At least one access field must be provided');
    }

    if (updateData.isAdmin === false && existingAccount.isAdmin) {
      await this.ensureAnotherAdminExists(accountId);
    }

    const updatedAccount = await this.userService.updateManagedAccount(accountId, updateData);

    return {
      account: this.serializeAccount(updatedAccount),
    };
  }

  async deleteAccount(accountId: number, actorId: number) {
    if (accountId === actorId) {
      throw new BadRequestException('You cannot delete your own account');
    }

    const existingAccount = await this.userService.findById(accountId);
    if (!existingAccount) {
      throw new NotFoundException('Account not found');
    }

    if (existingAccount.isAdmin) {
      await this.ensureAnotherAdminExists(accountId);
    }

    await this.userService.deleteManagedAccount(accountId);

    return {
      success: true,
    };
  }

  private serializeAccount(account: ManagedAccount): ManagedAccountResponse {
    const access = {
      basis: account.basisAccess,
      whsTours: account.whsToursAccess,
      ova: account.ovaAccess,
      japGpp: account.japGppAccess,
      maintenanceInspections: account.maintenanceInspectionsAccess,
    };

    return {
      id: account.id,
      email: account.email,
      name: account.name,
      departments: account.departments
        .map((link) => link.department),
      isAdmin: account.isAdmin,
      access,
      hasAnyAccess: account.isAdmin || Object.values(access).some(Boolean),
    };
  }

  private buildAccessUpdate(updateAccountAccessDto: UpdateAccountAccessDto): Prisma.UserUpdateInput {
    const updateData: Prisma.UserUpdateInput = {};

    this.assignBoolean(updateAccountAccessDto, 'isAdmin', updateData);
    this.assignBoolean(updateAccountAccessDto, 'basisAccess', updateData);
    this.assignBoolean(updateAccountAccessDto, 'whsToursAccess', updateData);
    this.assignBoolean(updateAccountAccessDto, 'ovaAccess', updateData);
    this.assignBoolean(updateAccountAccessDto, 'japGppAccess', updateData);
    this.assignBoolean(
      updateAccountAccessDto,
      'maintenanceInspectionsAccess',
      updateData,
    );

    return updateData;
  }

  private assignBoolean(
    source: UpdateAccountAccessDto,
    field: keyof UpdateAccountAccessDto,
    target: Prisma.UserUpdateInput,
  ) {
    if (!Object.prototype.hasOwnProperty.call(source, field)) {
      return;
    }

    target[field] = this.readBoolean(source, field);
  }

  private readBoolean<T extends object>(source: T, field: keyof T) {
    const value = source[field];

    if (value === undefined) {
      return false;
    }

    if (typeof value !== 'boolean') {
      throw new BadRequestException(`${String(field)} must be a boolean`);
    }

    return value;
  }

  private normalizeEmail(email: string) {
    const normalizedEmail = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailRegex.test(normalizedEmail)) {
      throw new BadRequestException('A valid email address is required');
    }

    return normalizedEmail;
  }

  private normalizePassword(password: string) {
    const normalizedPassword = password.trim();

    if (normalizedPassword.length < 6) {
      throw new BadRequestException('Password must be at least 6 characters long');
    }

    return normalizedPassword;
  }

  private normalizeName(name?: string) {
    const normalizedName = name?.trim();
    return normalizedName ? normalizedName : null;
  }

  private normalizeDepartmentIds(departmentIds?: number[]) {
    if (departmentIds === undefined) {
      return [] as number[];
    }

    if (!Array.isArray(departmentIds)) {
      throw new BadRequestException('departmentIds must be an array');
    }

    const uniqueDepartmentIds = Array.from(new Set(departmentIds));
    if (uniqueDepartmentIds.some((id) => !Number.isInteger(id) || id <= 0)) {
      throw new BadRequestException('departmentIds must contain positive integers');
    }

    return uniqueDepartmentIds;
  }

  private async assertDepartmentsExist(departmentIds: number[]) {
    if (departmentIds.length === 0) {
      return;
    }

    const count = await this.prisma.department.count({
      where: {
        id: {
          in: departmentIds,
        },
      },
    });

    if (count !== departmentIds.length) {
      throw new BadRequestException('One or more departments do not exist');
    }
  }

  private async ensureAnotherAdminExists(excludedUserId: number) {
    const remainingAdminCount = await this.userService.countAdmins(excludedUserId);
    if (remainingAdminCount === 0) {
      throw new BadRequestException('At least one admin account must remain');
    }
  }
}
