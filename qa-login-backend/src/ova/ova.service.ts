import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UserService } from '../user/user.service';
import { CreateOvaTicketDto, UpdateOvaTicketDto } from './dto/ova-ticket.dto';

const ovaUserSelect = {
  id: true,
  email: true,
  name: true,
} satisfies Prisma.UserSelect;

const ovaTicketSelect = {
  id: true,
  status: true,
  currentStep: true,
  findingDate: true,
  ovaType: true,
  reasons: true,
  otherReason: true,
  incidentDescription: true,
  createdAt: true,
  updatedAt: true,
  createdBy: {
    select: ovaUserSelect,
  },
  lastEditedBy: {
    select: ovaUserSelect,
  },
} satisfies Prisma.OvaTicketSelect;

type OvaTicketRecord = Prisma.OvaTicketGetPayload<{
  select: typeof ovaTicketSelect;
}>;

type OvaActor = {
  id: number;
  isAdmin: boolean;
  basisAccess: boolean;
  ovaAccess: boolean;
};

@Injectable()
export class OvaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly userService: UserService,
  ) {}

  async listTickets(actorId: number) {
    await this.assertCanAccessOva(actorId);

    const tickets = (await this.prisma.ovaTicket.findMany({
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      select: ovaTicketSelect,
    })) as OvaTicketRecord[];

    return {
      tickets: tickets.map((ticket) => this.serializeTicket(ticket)),
    };
  }

  async getTicket(ticketId: number, actorId: number) {
    await this.assertCanAccessOva(actorId);

    const ticket = (await this.prisma.ovaTicket.findUnique({
      where: { id: ticketId },
      select: ovaTicketSelect,
    })) as OvaTicketRecord | null;

    if (!ticket) {
      throw new NotFoundException('OVA-ticket niet gevonden');
    }

    return {
      ticket: this.serializeTicket(ticket),
    };
  }

  async createTicket(actorId: number, dto: CreateOvaTicketDto) {
    await this.assertCanAccessOva(actorId);

    const ticket = (await this.prisma.ovaTicket.create({
      data: this.buildCreateData(dto, actorId),
      select: ovaTicketSelect,
    })) as OvaTicketRecord;

    return {
      ticket: this.serializeTicket(ticket),
    };
  }

  async updateTicket(
    ticketId: number,
    actorId: number,
    dto: UpdateOvaTicketDto,
  ) {
    await this.assertCanAccessOva(actorId);

    const existingTicket = await this.prisma.ovaTicket.findUnique({
      where: { id: ticketId },
      select: {
        id: true,
        status: true,
        currentStep: true,
        incidentDescription: true,
      },
    });

    if (!existingTicket) {
      throw new NotFoundException('OVA-ticket niet gevonden');
    }

    const ticket = (await this.prisma.ovaTicket.update({
      where: { id: ticketId },
      data: this.buildUpdateData(dto, actorId, existingTicket),
      select: ovaTicketSelect,
    })) as OvaTicketRecord;

    return {
      ticket: this.serializeTicket(ticket),
    };
  }

  private async assertCanAccessOva(actorId: number): Promise<OvaActor> {
    const actor = await this.assertActorExists(actorId);

    if (!actor.isAdmin && !actor.ovaAccess && !actor.basisAccess) {
      throw new ForbiddenException('OVA-toegang is vereist');
    }

    return actor;
  }

  private async assertActorExists(actorId: number): Promise<OvaActor> {
    const actor = await this.userService.findById(actorId);
    if (!actor) {
      throw new UnauthorizedException('Gebruiker bestaat niet');
    }

    return actor;
  }

  private buildCreateData(
    dto: CreateOvaTicketDto,
    actorId: number,
  ): Prisma.OvaTicketUncheckedCreateInput {
    const currentStep = this.normalizeCreateCurrentStep(dto.currentStep);
    const incidentDescription =
      this.hasField(dto, 'incidentDescription')
        ? this.normalizeOptionalText(dto.incidentDescription)
        : null;

    const data: Prisma.OvaTicketUncheckedCreateInput = {
      createdById: actorId,
      lastEditedById: actorId,
      status: this.deriveTicketStatus({
        currentStep,
        incidentDescription,
      }),
      currentStep,
      reasons: this.hasField(dto, 'reasons') ? this.normalizeReasons(dto.reasons) : [],
    };

    if (this.hasField(dto, 'findingDate')) {
      data.findingDate = this.normalizeDate(dto.findingDate, {
        fieldName: 'Datum vaststelling',
      });
    }
    if (this.hasField(dto, 'ovaType')) {
      data.ovaType = this.normalizeOptionalText(dto.ovaType);
    }
    if (this.hasField(dto, 'otherReason')) {
      data.otherReason = this.normalizeOptionalText(dto.otherReason);
    }
    if (this.hasField(dto, 'incidentDescription')) {
      data.incidentDescription = incidentDescription;
    }

    return data;
  }

  private buildUpdateData(
    dto: UpdateOvaTicketDto,
    actorId: number,
    existingTicket: {
      status: string;
      currentStep: number;
      incidentDescription: string | null;
    },
  ): Prisma.OvaTicketUncheckedUpdateInput {
    const currentStep = this.resolveNextCurrentStep(
      dto.currentStep,
      existingTicket.currentStep,
    );
    const incidentDescription =
      dto.incidentDescription === undefined
        ? existingTicket.incidentDescription
        : this.normalizeOptionalText(dto.incidentDescription);

    const data: Prisma.OvaTicketUncheckedUpdateInput = {
      lastEditedById: actorId,
      status: this.deriveTicketStatus({
        currentStep,
        incidentDescription,
        existingStatus: existingTicket.status,
      }),
      currentStep,
    };

    if (this.hasField(dto, 'findingDate')) {
      data.findingDate = this.normalizeDate(dto.findingDate, {
        fieldName: 'Datum vaststelling',
      });
    }
    if (this.hasField(dto, 'ovaType')) {
      data.ovaType = this.normalizeOptionalText(dto.ovaType);
    }
    if (this.hasField(dto, 'reasons')) {
      data.reasons = this.normalizeReasons(dto.reasons);
    }
    if (this.hasField(dto, 'otherReason')) {
      data.otherReason = this.normalizeOptionalText(dto.otherReason);
    }
    if (this.hasField(dto, 'incidentDescription')) {
      data.incidentDescription = incidentDescription;
    }

    return data;
  }

  private hasField<T extends object>(
    dto: T,
    field: keyof T,
  ): boolean {
    return Object.prototype.hasOwnProperty.call(dto, field);
  }

  private normalizeCreateCurrentStep(value?: number) {
    if (value === undefined) {
      return 1;
    }

    return this.normalizeCurrentStep(value);
  }

  private resolveNextCurrentStep(value: number | undefined, existingStep: number) {
    if (value === undefined) {
      return existingStep;
    }

    const normalizedValue = this.normalizeCurrentStep(value);
    return normalizedValue > existingStep ? normalizedValue : existingStep;
  }

  private deriveTicketStatus({
    currentStep,
    incidentDescription,
    existingStatus,
  }: {
    currentStep: number;
    incidentDescription?: string | null;
    existingStatus?: string;
  }) {
    if (existingStatus?.trim().toLowerCase() === 'open') {
      return 'open';
    }

    return currentStep >= 3 || (incidentDescription?.trim().length ?? 0) > 0
      ? 'open'
      : 'incomplete';
  }

  private normalizeDate(
    value: string | null | undefined,
    { fieldName }: { fieldName: string },
  ) {
    if (value === undefined) {
      return undefined;
    }

    if (value === null) {
      return null;
    }

    const normalizedValue = value.trim();
    if (!normalizedValue) {
      return null;
    }

    const parsed = new Date(normalizedValue);
    if (Number.isNaN(parsed.getTime())) {
      throw new BadRequestException(`${fieldName} is ongeldig`);
    }

    return parsed;
  }

  private normalizeOptionalText(value?: string | null) {
    if (value === undefined) {
      return undefined;
    }

    if (value === null) {
      return null;
    }

    const normalizedValue = value.trim();
    return normalizedValue ? normalizedValue : null;
  }

  private normalizeReasons(value?: string[]) {
    if (value === undefined) {
      return [];
    }

    if (!Array.isArray(value)) {
      throw new BadRequestException(
        'Aanleidingen moeten als lijst verzonden worden',
      );
    }

    return Array.from(
      new Set(
        value
          .map((item) => (typeof item === 'string' ? item.trim() : ''))
          .filter((item) => item.length > 0),
      ),
    );
  }

  private normalizeCurrentStep(value?: number) {
    if (!Number.isInteger(value)) {
      throw new BadRequestException('currentStep moet een geheel getal zijn');
    }

    return Math.min(3, Math.max(1, value));
  }

  private serializeTicket(ticket: OvaTicketRecord) {
    return {
      id: ticket.id,
      status: ticket.status,
      currentStep: ticket.currentStep,
      findingDate: ticket.findingDate?.toISOString() ?? null,
      ovaType: ticket.ovaType,
      reasons: ticket.reasons,
      otherReason: ticket.otherReason,
      incidentDescription: ticket.incidentDescription,
      createdAt: ticket.createdAt.toISOString(),
      updatedAt: ticket.updatedAt.toISOString(),
      createdBy: ticket.createdBy,
      lastEditedBy: ticket.lastEditedBy,
    };
  }
}
