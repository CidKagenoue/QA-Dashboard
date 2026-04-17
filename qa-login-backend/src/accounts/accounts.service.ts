import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateAccountDto,
  UpdateAccountAccessDto,
} from './dto/account-management.dto';
import { ManagedAccount, UserService } from '../user/user.service';
import { NotificationsService } from '../notifications/notifications.service';

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

type AccessState = {
  isAdmin: boolean;
  basisAccess: boolean;
  whsToursAccess: boolean;
  ovaAccess: boolean;
  japGppAccess: boolean;
  maintenanceInspectionsAccess: boolean;
};

@Injectable()
export class AccountsService {
  constructor(
    private readonly userService: UserService,
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
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

    await this.notificationsService.notifyUser({
      recipientUserId: account.id,
      type: NotificationType.ACCOUNT_CREATED,
      title: 'Account aangemaakt',
      body: this.buildAccountCreatedMessage(account),
      metadata: {
        accountId: account.id,
        email: account.email,
        name: account.name,
        access: this.serializeAccessState(account),
        departments: account.departments.map((link) => link.department.name),
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
    const existingAccount = await this.userService.findManagedById(accountId);
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
    const accessChanges = this.describeAccessChanges(existingAccount, updatedAccount);

    await this.notificationsService.notifyUser({
      recipientUserId: updatedAccount.id,
      type: NotificationType.ACCOUNT_ACCESS_CHANGED,
      title: 'Toegangsrechten aangepast',
      body: accessChanges
        ? `Je accountrechten zijn aangepast: ${accessChanges}.`
        : 'Je accountrechten zijn bijgewerkt door een administrator.',
      metadata: {
        accountId: updatedAccount.id,
        access: this.serializeAccessState(updatedAccount),
      },
    });

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

  private buildAccountCreatedMessage(account: ManagedAccount) {
    const displayName = account.name?.trim() || account.email;
    const accessLabel = this.describeAccessState(this.serializeAccessState(account));
    const departments = account.departments.map((link) => link.department.name);
    const departmentLabel = departments.length > 0
      ? ` Afdelingen: ${departments.join(', ')}.`
      : '';

    return `Je account voor ${displayName} (${account.email}) is aangemaakt. Rechten: ${accessLabel}.${departmentLabel}`;
  }

  private serializeAccessState(account: ManagedAccount): AccessState {
    return {
      isAdmin: account.isAdmin,
      basisAccess: account.basisAccess,
      whsToursAccess: account.whsToursAccess,
      ovaAccess: account.ovaAccess,
      japGppAccess: account.japGppAccess,
      maintenanceInspectionsAccess: account.maintenanceInspectionsAccess,
    };
  }

  private describeAccessState(access: AccessState) {
    const labels = [
      access.isAdmin ? 'Admin' : null,
      access.basisAccess ? 'Basis' : null,
      access.whsToursAccess ? 'WHS-Tours' : null,
      access.ovaAccess ? 'OVA' : null,
      access.japGppAccess ? 'JAP & GPP' : null,
      access.maintenanceInspectionsAccess ? 'Onderhoud & Keuringen' : null,
    ].filter((value): value is string => Boolean(value));

    return labels.length > 0 ? labels.join(', ') : 'geen modules';
  }

  private describeAccessChanges(previous: ManagedAccount, next: ManagedAccount) {
    const previousState = this.serializeAccessState(previous);
    const nextState = this.serializeAccessState(next);
    const changes: string[] = [];

    if (previousState.isAdmin !== nextState.isAdmin) {
      changes.push(`admin ${nextState.isAdmin ? 'aan' : 'uit'}`);
    }
    if (previousState.basisAccess !== nextState.basisAccess) {
      changes.push(`basis ${nextState.basisAccess ? 'aan' : 'uit'}`);
    }
    if (previousState.whsToursAccess !== nextState.whsToursAccess) {
      changes.push(`whs-tours ${nextState.whsToursAccess ? 'aan' : 'uit'}`);
    }
    if (previousState.ovaAccess !== nextState.ovaAccess) {
      changes.push(`ova ${nextState.ovaAccess ? 'aan' : 'uit'}`);
    }
    if (previousState.japGppAccess !== nextState.japGppAccess) {
      changes.push(`jap & gpp ${nextState.japGppAccess ? 'aan' : 'uit'}`);
    }
    if (previousState.maintenanceInspectionsAccess !== nextState.maintenanceInspectionsAccess) {
      changes.push(
        `onderhoud & keuringen ${nextState.maintenanceInspectionsAccess ? 'aan' : 'uit'}`,
      );
    }

    return changes.join(', ');
  }
}
