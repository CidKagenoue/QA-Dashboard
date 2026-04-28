import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { NotificationType } from '@prisma/client';
import { NotificationService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  AssignableOvaUser,
  UserService,
} from '../user/user.service';
import {
  CreateOvaTicketDto,
  OvaExternalResponsibleDto,
  OvaFollowUpActionDto,
  UpdateOvaFollowUpActionDto,
  UpdateOvaTicketDto,
} from './dto/ova-ticket.dto';


const ovaUserSelect = {
  id: true,
  email: true,
  name: true,
} satisfies Prisma.UserSelect;

const ovaExternalContactSelect = {
  id: true,
  firstName: true,
  lastName: true,
  email: true,
} satisfies Prisma.OvaExternalContactSelect;

const ovaActionSelect = {
  id: true,
  type: true,
  description: true,
  dueDate: true,
  status: true,
  assigneeType: true,
  createdAt: true,
  updatedAt: true,
  internalAssignee: {
    select: ovaUserSelect,
  },
  externalContact: {
    select: ovaExternalContactSelect,
  },
} satisfies Prisma.OvaFollowUpActionSelect;

const ovaTicketSelect = {
  id: true,
  status: true,
  currentStep: true,
  findingDate: true,
  ovaType: true,
  reasons: true,
  otherReason: true,
  incidentDescription: true,
  causeAnalysisMethod: true,
  causeAnalysisNotes: true,
  followUpActions: true,
  effectivenessDate: true,
  effectivenessNotes: true,
  closureNotes: true,
  closedAt: true,
  createdAt: true,
  updatedAt: true,
  createdBy: {
    select: ovaUserSelect,
  },
  lastEditedBy: {
    select: ovaUserSelect,
  },
  closedBy: {
    select: ovaUserSelect,
  },
  actions: {
    orderBy: [{ type: 'asc' }, { dueDate: 'asc' }, { id: 'asc' }],
    select: ovaActionSelect,
  },
} satisfies Prisma.OvaTicketSelect;

type OvaTicketRecord = Prisma.OvaTicketGetPayload<{
  select: typeof ovaTicketSelect;
}>;

type OvaActionRecord = Prisma.OvaFollowUpActionGetPayload<{
  select: typeof ovaActionSelect;
}>;

const assignedActionSelect = {
  ...ovaActionSelect,
  ticket: {
    select: {
      id: true,
      status: true,
      currentStep: true,
      findingDate: true,
      ovaType: true,
    },
  },
} satisfies Prisma.OvaFollowUpActionSelect;

type AssignedActionRecord = Prisma.OvaFollowUpActionGetPayload<{
  select: typeof assignedActionSelect;
}>;

type OvaActor = {
  id: number;
  isAdmin: boolean;
  basisAccess: boolean;
  ovaAccess: boolean;
};

type NormalizedTicketStatus = 'incomplete' | 'open' | 'closed';
type NormalizedActionStatus = 'ok' | 'nok';
type NormalizedActionType = 'corrective' | 'preventive';
type NormalizedAssigneeType = 'internal' | 'external';

type NormalizedExternalResponsibleInput = {
  id?: number;
  firstName?: string;
  lastName?: string;
  email?: string | null;
};

type NormalizedFollowUpActionInput = {
  id?: number;
  type: NormalizedActionType;
  description: string;
  dueDate: Date;
  status: NormalizedActionStatus;
  assigneeType: NormalizedAssigneeType;
  internalAssigneeId?: number | null;
  externalResponsible?: NormalizedExternalResponsibleInput | null;
};

type OvaFollowUpActionWriteData = Omit<
  Prisma.OvaFollowUpActionUncheckedCreateInput,
  'ticketId'
>;

type InternalAssignmentSnapshot = {
  actionId: number;
  internalAssigneeId: number;
};

type TicketMutation<TTicketData> = {
  ticketData: TTicketData;
  actions?: NormalizedFollowUpActionInput[];
  requestedStatus?: NormalizedTicketStatus;
};

@Injectable()
export class OvaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly userService: UserService,
    private readonly notificationsService: NotificationService,
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

  async listAssignableUsers(actorId: number) {
    await this.assertCanAccessOva(actorId);

    const users = await this.userService.listAssignableOvaUsers();

    return {
      users: users.map((user) => this.serializeAssignableUser(user)),
    };
  }

  async listExternalContacts(actorId: number, query?: string) {
    await this.assertCanAccessOva(actorId);

    const normalizedQuery = query?.trim();
    const contacts = await this.prisma.ovaExternalContact.findMany({
      where: normalizedQuery
        ? {
            OR: [
              {
                firstName: {
                  contains: normalizedQuery,
                  mode: Prisma.QueryMode.insensitive,
                },
              },
              {
                lastName: {
                  contains: normalizedQuery,
                  mode: Prisma.QueryMode.insensitive,
                },
              },
              {
                email: {
                  contains: normalizedQuery,
                  mode: Prisma.QueryMode.insensitive,
                },
              },
            ],
          }
        : undefined,
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take: 10,
      select: ovaExternalContactSelect,
    });

    return {
      contacts: contacts.map((contact) =>
        this.serializeExternalContact(contact),
      ),
    };
  }

  async createTicket(actorId: number, dto: CreateOvaTicketDto) {
    await this.assertCanAccessOva(actorId);

    const mutation = this.normalizeCreateInput(dto, actorId);

    const ticket = await this.prisma.$transaction(async (tx) => {
      const actionCount = mutation.actions?.length ?? 0;
      const requestedStatus = mutation.requestedStatus;
      const isClosing = requestedStatus === 'closed';

      const createdTicket = await tx.ovaTicket.create({
        data: {
          ...mutation.ticketData,
          findingDate: mutation.ticketData.findingDate ?? new Date(),
          currentStep: isClosing
            ? 7
            : mutation.ticketData.currentStep ?? undefined,
          status: this.deriveTicketStatus({
            requestedStatus,
            actionCount,
          }),
          closedAt: isClosing ? new Date() : undefined,
          closedById: isClosing ? actorId : undefined,
        },
        select: { id: true },
      });

      if (mutation.actions !== undefined) {
        await this.syncFollowUpActions(tx, createdTicket.id, mutation.actions);
      }

      const ticketRecord = (await tx.ovaTicket.findUnique({
        where: { id: createdTicket.id },
        select: ovaTicketSelect,
      })) as OvaTicketRecord | null;

      if (!ticketRecord) {
        throw new NotFoundException('OVA-ticket niet gevonden');
      }

      return ticketRecord;
    });

    await this.notifyInternalAssignmentChanges({
      actorId,
      ticketId: ticket.id,
      before: [],
      after: ticket.actions,
    });

    // Notificatie-logica toevoegen
    // 1. Bepaal meldingstekst en het bijbehorende notification type
    let notificationTitle = 'OVA-ticket aangemaakt';
    let notificationBody = `Ticket #${ticket.id} is aangemaakt.`;
    let notificationType: NotificationType = NotificationType.OVA_TICKET_CREATED;
    if (dto.ovaType) {
      // Maak type-vergelijking robuuster: verwijder spaties en hoofdletters
      const type = dto.ovaType.replace(/\s+/g, '').toLowerCase();
      if (type === 'ova1') {
        notificationTitle = 'OVA1 ticket aangemaakt';
        notificationBody = `OVA ticket #${ticket.id} is aangemaakt.`;
        notificationType = NotificationType.OVA_1;
      } else if (type === 'ova2') {
        notificationTitle = 'OVA2 ticket aangemaakt';
        notificationBody = `OVA ticket #${ticket.id} is aangemaakt.`;
        notificationType = NotificationType.OVA_2;
      } else if (type === 'ova3') {
        notificationTitle = 'OVA3 ticket aangemaakt';
        notificationBody = `OVA ticket #${ticket.id} is aangemaakt.`;
        notificationType = NotificationType.OVA_3;
      } else if (type === 'nearmiss' || type === 'nearmiss') {
        notificationTitle = 'Near miss ticket aangemaakt';
        notificationBody = `Ticket #${ticket.id} is aangemaakt.`;
      } else {
        notificationTitle = 'OVA-ticket aangemaakt';
        notificationBody = `Ticket #${ticket.id} is aangemaakt.`;
      }
    }

    // 2. Melding aanmaken; de NotificationService controleert nu centraal de user settings.
    console.log('[OVA] Probeer melding aan te maken:', {
      actorId,
      notificationTitle,
      ticketId: ticket.id,
      ovaType: dto.ovaType,
      notificationType,
    });
    try {
      const notificationCreated = await this.notificationsService.notifyUser({
        recipientUserId: actorId,
        type: notificationType,
        title: notificationTitle,
        body: notificationBody,
        metadata: { ticketId: ticket.id, ovaType: dto.ovaType },
      });
      if (notificationCreated) {
        console.log('[OVA] Melding succesvol aangemaakt voor ticket', ticket.id);
      } else {
        console.log('[OVA] Melding overgeslagen vanwege notificatievoorkeur voor ticket', ticket.id);
      }
    } catch (err) {
      console.error('[OVA] Fout bij aanmaken melding:', err);
    }

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
        actions: {
          select: {
            id: true,
            internalAssigneeId: true,
          },
        },
      },
    });

    if (!existingTicket) {
      throw new NotFoundException('OVA-ticket niet gevonden');
    }

    const mutation = this.normalizeUpdateInput(dto, actorId);
    const beforeAssignments: InternalAssignmentSnapshot[] =
      existingTicket.actions
        .filter(
          (action) =>
            Number.isInteger(action.internalAssigneeId) &&
            Number(action.internalAssigneeId) > 0,
        )
        .map((action) => ({
          actionId: action.id,
          internalAssigneeId: Number(action.internalAssigneeId),
        }));

    const ticket = await this.prisma.$transaction(async (tx) => {
      if (mutation.actions !== undefined) {
        await this.syncFollowUpActions(tx, ticketId, mutation.actions);
      }

      const actionCount =
        mutation.actions?.length ?? existingTicket.actions.length;
      const requestedStatus = mutation.requestedStatus;
      const isClosing = requestedStatus === 'closed';

      const ticketRecord = (await tx.ovaTicket.update({
        where: { id: ticketId },
        data: {
          ...mutation.ticketData,
          status: this.deriveTicketStatus({
            requestedStatus,
            actionCount,
            existingStatus: existingTicket.status,
          }),
          closedAt: isClosing ? new Date() : undefined,
          closedById: isClosing ? actorId : undefined,
          currentStep: isClosing ? 7 : mutation.ticketData.currentStep,
        },
        select: ovaTicketSelect,
      })) as OvaTicketRecord;

      return ticketRecord;
    });

    await this.notifyInternalAssignmentChanges({
      actorId,
      ticketId: ticket.id,
      before: beforeAssignments,
      after: ticket.actions,
    });

    const previousStatus = existingTicket.status.trim().toLowerCase();
    const nextStatus = ticket.status.trim().toLowerCase();
    if (previousStatus !== nextStatus) {
      const recipientIds = Array.from(
        new Set(
          [
            ticket.createdBy.id,
            ticket.lastEditedBy.id,
            ...ticket.actions
              .map((action) => action.internalAssignee?.id)
              .filter((id): id is number => Number.isInteger(id) && id > 0),
          ].filter((id) => id !== actorId),
        ),
      );

      await this.notificationsService.notifyUsers({
        recipientUserIds: recipientIds,
        // type: NotificationType.OVA_TICKET_STATUS_CHANGED, // Niet gedefinieerd in NotificationType
        type: NotificationType.OVA_TICKET_CREATED, // Tijdelijk alternatief
        title: `OVA ticket #${ticket.id} status gewijzigd`,
        body: `Status veranderde van ${existingTicket.status} naar ${ticket.status}.`,
        metadata: {
          ticketId: ticket.id,
          previousStatus: existingTicket.status,
          nextStatus: ticket.status,
        },
      });
    }

    return {
      ticket: this.serializeTicket(ticket),
    };
  }
  private async notifyInternalAssignmentChanges(params: {
    actorId: number;
    ticketId: number;
    before: InternalAssignmentSnapshot[];
    after: Array<{
      id: number;
      type: string;
      description: string;
      dueDate: Date;
      internalAssignee: { id: number } | null;
    }>;
  }) {
    const beforeMap = new Map<number, number>();
    for (const item of params.before) {
      beforeMap.set(item.actionId, item.internalAssigneeId);
    }

    const newlyAssignedUserIds = new Set<number>();
    const reassignedUserIds = new Set<number>();

    for (const action of params.after) {
      const nextAssigneeId = action.internalAssignee?.id;
      if (!nextAssigneeId || nextAssigneeId === params.actorId) {
        continue;
      }

      const previousAssigneeId = beforeMap.get(action.id);
      if (!previousAssigneeId) {
        newlyAssignedUserIds.add(nextAssigneeId);
        continue;
      }

      if (previousAssigneeId !== nextAssigneeId) {
        reassignedUserIds.add(nextAssigneeId);
      }
    }

    if (newlyAssignedUserIds.size > 0) {
      const sampleAction = params.after.find(
        (action) =>
          action.internalAssignee?.id !== undefined &&
          action.internalAssignee?.id !== params.actorId,
      );

      await this.notificationsService.notifyUsers({
        recipientUserIds: Array.from(newlyAssignedUserIds),
        // type: NotificationType.OVA_ACTION_ASSIGNED, // Niet gedefinieerd in NotificationType
        type: NotificationType.OVA_NEW_ACTION, // Tijdelijk alternatief
        title: `Nieuwe OVA-actie toegewezen`,
        body: sampleAction
          ? `Ticket #${params.ticketId}: ${this.describeAction(sampleAction)} is nu aan jou toegewezen.`
          : `Je hebt een nieuwe OVA-opvolgactie op ticket #${params.ticketId}.`,
        metadata: {
          ticketId: params.ticketId,
        },
      });
    }

    if (reassignedUserIds.size > 0) {
      const sampleAction = params.after.find(
        (action) =>
          action.internalAssignee?.id !== undefined &&
          action.internalAssignee?.id !== params.actorId,
      );

      await this.notificationsService.notifyUsers({
        recipientUserIds: Array.from(reassignedUserIds),
        // type: NotificationType.OVA_ACTION_REASSIGNED, // Niet gedefinieerd in NotificationType
        type: NotificationType.OVA_NEW_ACTION, // Tijdelijk alternatief
        title: `OVA-actie herverdeeld`,
        body: sampleAction
          ? `Ticket #${params.ticketId}: ${this.describeAction(sampleAction)} is opnieuw aan jou toegewezen.`
          : `Een OVA-opvolgactie op ticket #${params.ticketId} werd aan jou toegewezen.`,
        metadata: {
          ticketId: params.ticketId,
        },
      });
    }
  }

  private describeAction(action: {
    type: string;
    description: string;
    dueDate: Date;
  }) {
    const actionTypeLabel =
      action.type.trim().toLowerCase() === 'corrective'
        ? 'corrigerende actie'
        : 'preventieve actie';
    const dueDateLabel = action.dueDate
      ? ` Deadline: ${this.formatActionDate(action.dueDate)}.`
      : '';

    return `${actionTypeLabel} "${action.description}"${dueDateLabel}`;
  }

  private formatActionDate(value: Date) {
    if (Number.isNaN(value.getTime())) {
      return '-';
    }

    return new Intl.DateTimeFormat('nl-BE', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    }).format(value);
  }

  async listMyActions(actorId: number) {
    await this.assertActorExists(actorId);

    const actions = (await this.prisma.ovaFollowUpAction.findMany({
      where: {
        internalAssigneeId: actorId,
        ticket: {
          currentStep: {
            lte: 5,
          },
          status: {
            not: 'closed',
          },
        },
      },
      orderBy: [{ dueDate: 'asc' }, { id: 'asc' }],
      select: assignedActionSelect,
    })) as AssignedActionRecord[];

    return {
      actions: actions.map((action) => this.serializeAssignedAction(action)),
    };
  }

  async updateAction(
    actionId: number,
    actorId: number,
    dto: UpdateOvaFollowUpActionDto,
  ) {
    const actor = await this.assertActorExists(actorId);

    const existingAction = await this.prisma.ovaFollowUpAction.findUnique({
      where: { id: actionId },
      select: {
        id: true,
        internalAssigneeId: true,
      },
    });

    if (!existingAction) {
      throw new NotFoundException('Opvolgactie niet gevonden');
    }

    if (
      existingAction.internalAssigneeId !== actor.id &&
      !actor.isAdmin &&
      !actor.ovaAccess &&
      !actor.basisAccess
    ) {
      throw new ForbiddenException(
        'Je mag deze opvolgactie niet aanpassen',
      );
    }

    const status = this.normalizeActionStatus(dto.status, {
      fieldName: 'status opvolgactie',
    });

    const action = (await this.prisma.ovaFollowUpAction.update({
      where: { id: actionId },
      data: {
        status,
      },
      select: ovaActionSelect,
    })) as OvaActionRecord;

    return {
      action: this.serializeAction(action),
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

  private normalizeCreateInput(
    dto: CreateOvaTicketDto | UpdateOvaTicketDto,
    actorId: number,
  ): TicketMutation<Prisma.OvaTicketUncheckedCreateInput> {
    const ticketData: Prisma.OvaTicketUncheckedCreateInput = {
      createdById: actorId,
      lastEditedById: actorId,
    };

    this.assignTicketFields(ticketData, dto);

    return {
      ticketData,
      actions: this.readActionInput(dto),
      requestedStatus: this.readRequestedStatus(dto),
    };
  }

  private normalizeUpdateInput(
    dto: CreateOvaTicketDto | UpdateOvaTicketDto,
    actorId: number,
  ): TicketMutation<Prisma.OvaTicketUncheckedUpdateInput> {
    const ticketData: Prisma.OvaTicketUncheckedUpdateInput = {
      lastEditedById: actorId,
    };

    this.assignTicketFields(ticketData, dto);

    return {
      ticketData,
      actions: this.readActionInput(dto),
      requestedStatus: this.readRequestedStatus(dto),
    };
  }

  private assignTicketFields(
    data:
      | Prisma.OvaTicketUncheckedCreateInput
      | Prisma.OvaTicketUncheckedUpdateInput,
    dto: CreateOvaTicketDto | UpdateOvaTicketDto,
  ) {
    if (Object.prototype.hasOwnProperty.call(dto, 'findingDate')) {
      data.findingDate = this.normalizeDate(dto.findingDate, {
        fieldName: 'Datum vaststelling',
      });
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'ovaType')) {
      data.ovaType = this.normalizeOptionalText(dto.ovaType);
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'reasons')) {
      data.reasons = this.normalizeReasons(dto.reasons);
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'otherReason')) {
      data.otherReason = this.normalizeOptionalText(dto.otherReason);
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'incidentDescription')) {
      data.incidentDescription = this.normalizeOptionalText(
        dto.incidentDescription,
      );
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'causeAnalysisMethod')) {
      data.causeAnalysisMethod = this.normalizeOptionalText(
        dto.causeAnalysisMethod,
      );
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'causeAnalysisNotes')) {
      data.causeAnalysisNotes = this.normalizeOptionalText(
        dto.causeAnalysisNotes,
      );
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'followUpActions')) {
      data.followUpActions = this.normalizeOptionalText(dto.followUpActions);
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'effectivenessDate')) {
      data.effectivenessDate = this.normalizeDate(dto.effectivenessDate, {
        fieldName: 'Datum effectiviteitscontrole',
      });
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'effectivenessNotes')) {
      data.effectivenessNotes = this.normalizeOptionalText(
        dto.effectivenessNotes,
      );
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'closureNotes')) {
      data.closureNotes = this.normalizeOptionalText(dto.closureNotes);
    }
    if (Object.prototype.hasOwnProperty.call(dto, 'currentStep')) {
      data.currentStep = this.normalizeCurrentStep(dto.currentStep);
    }

    return data;
  }

  private readRequestedStatus(
    dto: CreateOvaTicketDto | UpdateOvaTicketDto,
  ): NormalizedTicketStatus | undefined {
    if (!Object.prototype.hasOwnProperty.call(dto, 'status')) {
      return undefined;
    }

    return this.normalizeTicketStatus(dto.status);
  }

  private readActionInput(
    dto: CreateOvaTicketDto | UpdateOvaTicketDto,
  ): NormalizedFollowUpActionInput[] | undefined {
    if (!Object.prototype.hasOwnProperty.call(dto, 'actions')) {
      return undefined;
    }

    return this.normalizeFollowUpActions(dto.actions);
  }

  private async syncFollowUpActions(
    tx: Prisma.TransactionClient,
    ticketId: number,
    actions: NormalizedFollowUpActionInput[],
  ) {
    const existingActions = await tx.ovaFollowUpAction.findMany({
      where: { ticketId },
      select: { id: true },
    });

    const existingIds = new Set(existingActions.map((action) => action.id));
    const seenExistingIds = new Set<number>();

    for (const action of actions) {
      const actionData = await this.buildActionWriteData(tx, action);

      if (action.id !== undefined) {
        if (!existingIds.has(action.id)) {
          throw new BadRequestException(
            `Opvolgactie ${action.id} hoort niet bij dit ticket`,
          );
        }

        seenExistingIds.add(action.id);
        await tx.ovaFollowUpAction.update({
          where: { id: action.id },
          data: actionData,
        });
        continue;
      }

      // Nieuwe actie aanmaken
      const createdAction = await tx.ovaFollowUpAction.create({
        data: {
          ticketId,
          ...actionData,
        },
      });

      // Notificatie sturen naar verantwoordelijke
      if (action.assigneeType === 'internal' && action.internalAssigneeId) {
        const recipientUserId = action.internalAssigneeId;
        const actionTypeLabel = action.type === 'corrective' ? 'corrigerende actie' : 'preventieve actie';
        const body = `Er is een ${actionTypeLabel} aan jou toegewezen voor OVA-ticket #${ticketId}. Deadline: ${this.formatActionDate(action.dueDate)}.`;
        await this.notificationsService.notifyUser?.({
          recipientUserId,
          type: NotificationType.OVA_NEW_ACTION,
          title: `Nieuwe opvolgactie toegewezen (${actionTypeLabel})`,
          body,
          metadata: { ticketId, actionType: action.type, actionId: createdAction.id },
        });
      }
    }

    const deleteIds = existingActions
      .map((action) => action.id)
      .filter((id) => !seenExistingIds.has(id));

    if (deleteIds.length > 0) {
      await tx.ovaFollowUpAction.deleteMany({
        where: {
          ticketId,
          id: {
            in: deleteIds,
          },
        },
      });
    }
  }

  private async buildActionWriteData(
    tx: Prisma.TransactionClient,
    action: NormalizedFollowUpActionInput,
  ): Promise<OvaFollowUpActionWriteData> {
    if (action.assigneeType === 'internal') {
      const internalAssigneeId = action.internalAssigneeId;
      if (!internalAssigneeId) {
        throw new BadRequestException('Selecteer een verantwoordelijke');
      }

      const internalAssignee = await tx.user.findUnique({
        where: { id: internalAssigneeId },
        select: { id: true },
      });

      if (!internalAssignee) {
        throw new BadRequestException('Interne verantwoordelijke bestaat niet');
      }

      return {
        type: action.type,
        description: action.description,
        dueDate: action.dueDate,
        status: action.status,
        assigneeType: action.assigneeType,
        internalAssigneeId: internalAssignee.id,
        externalContactId: null,
      };
    }

    const externalResponsible = action.externalResponsible;
    if (!externalResponsible) {
      throw new BadRequestException('Selecteer een verantwoordelijke');
    }

    const externalContactId = await this.resolveExternalContactId(
      tx,
      externalResponsible,
    );

    return {
      type: action.type,
      description: action.description,
      dueDate: action.dueDate,
      status: action.status,
      assigneeType: action.assigneeType,
      internalAssigneeId: null,
      externalContactId,
    };
  }

  private async resolveExternalContactId(
    tx: Prisma.TransactionClient,
    contact: NormalizedExternalResponsibleInput,
  ) {
    if (contact.id !== undefined) {
      const existingById = await tx.ovaExternalContact.findUnique({
        where: { id: contact.id },
        select: { id: true },
      });

      if (existingById) {
        return existingById.id;
      }
    }

    const firstName = this.normalizeRequiredText(contact.firstName, {
      fieldName: 'Voornaam externe verantwoordelijke',
    });
    const lastName = this.normalizeRequiredText(contact.lastName, {
      fieldName: 'Achternaam externe verantwoordelijke',
    });
    const email = this.normalizeOptionalEmail(contact.email);

    const existingContact = await tx.ovaExternalContact.findFirst({
      where: {
        firstName: {
          equals: firstName,
          mode: Prisma.QueryMode.insensitive,
        },
        lastName: {
          equals: lastName,
          mode: Prisma.QueryMode.insensitive,
        },
        email: email
          ? {
              equals: email,
              mode: Prisma.QueryMode.insensitive,
            }
          : null,
      },
      select: { id: true },
    });

    if (existingContact) {
      return existingContact.id;
    }

    const createdContact = await tx.ovaExternalContact.create({
      data: {
        firstName,
        lastName,
        email,
      },
      select: { id: true },
    });

    return createdContact.id;
  }

  private deriveTicketStatus({
    requestedStatus,
    actionCount,
    existingStatus,
  }: {
    requestedStatus?: NormalizedTicketStatus;
    actionCount: number;
    existingStatus?: string;
  }): NormalizedTicketStatus {
    if (requestedStatus === 'closed') {
      return 'closed';
    }

    if (existingStatus?.toLowerCase() === 'closed') {
      return 'closed';
    }

    return actionCount > 0 ? 'open' : 'incomplete';
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

  private normalizeRequiredText(
    value: string | null | undefined,
    { fieldName }: { fieldName: string },
  ) {
    const normalizedValue = this.normalizeOptionalText(value);
    if (!normalizedValue) {
      throw new BadRequestException(`${fieldName} is verplicht`);
    }

    return normalizedValue;
  }

  private normalizeOptionalEmail(value?: string | null) {
    const normalizedValue = this.normalizeOptionalText(value);
    if (!normalizedValue) {
      return null;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedValue.toLowerCase())) {
      throw new BadRequestException('E-mailadres van externe verantwoordelijke is ongeldig');
    }

    return normalizedValue.toLowerCase();
  }

  private normalizeReasons(value?: string[]) {
    if (value === undefined) {
      return undefined;
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
    if (value === undefined) {
      return undefined;
    }

    if (!Number.isInteger(value)) {
      throw new BadRequestException('currentStep moet een geheel getal zijn');
    }

    return Math.min(7, Math.max(1, value));
  }

  private normalizeTicketStatus(value?: string | null): NormalizedTicketStatus {
    const normalizedValue = value?.trim().toLowerCase();
    if (!normalizedValue) {
      throw new BadRequestException('status is ongeldig');
    }

    if (normalizedValue === 'draft') {
      return 'incomplete';
    }
    if (normalizedValue === 'completed') {
      return 'closed';
    }
    if (
      normalizedValue === 'incomplete' ||
      normalizedValue === 'open' ||
      normalizedValue === 'closed'
    ) {
      return normalizedValue;
    }

    throw new BadRequestException(
      'status moet incomplete, open of closed zijn',
    );
  }

  private normalizeFollowUpActions(value?: OvaFollowUpActionDto[]) {
    if (value === undefined) {
      return undefined;
    }

    if (!Array.isArray(value)) {
      throw new BadRequestException(
        'Opvolgacties moeten als lijst verzonden worden',
      );
    }

    return value.map((action, index) =>
      this.normalizeFollowUpAction(action, index),
    );
  }

  private normalizeFollowUpAction(
    value: OvaFollowUpActionDto,
    index: number,
  ): NormalizedFollowUpActionInput {
    if (!value || typeof value !== 'object') {
      throw new BadRequestException(
        `Opvolgactie ${index + 1} is ongeldig`,
      );
    }

    const assigneeType = this.normalizeAssigneeType(value.assigneeType);

    return {
      id: this.normalizeOptionalId(value.id, `Opvolgactie ${index + 1}`),
      type: this.normalizeActionType(value.type),
      description: this.normalizeRequiredText(value.description, {
        fieldName: `Omschrijving opvolgactie ${index + 1}`,
      }),
      dueDate: this.normalizeRequiredDate(value.dueDate, {
        fieldName: `Deadline opvolgactie ${index + 1}`,
      }),
      status:
        value.status === undefined
          ? 'nok'
          : this.normalizeActionStatus(value.status, {
              fieldName: `Status opvolgactie ${index + 1}`,
            }),
      assigneeType,
      internalAssigneeId:
        assigneeType === 'internal'
          ? this.normalizeRequiredId(
              value.internalAssigneeId,
              'Selecteer een verantwoordelijke',
            )
          : null,
      externalResponsible:
        assigneeType === 'external'
          ? this.normalizeExternalResponsible(value.externalResponsible)
          : null,
    };
  }

  private normalizeExternalResponsible(value?: OvaExternalResponsibleDto | null) {
    if (!value || typeof value !== 'object') {
      throw new BadRequestException('Selecteer een verantwoordelijke');
    }

    const id = this.normalizeOptionalId(value.id, 'Externe verantwoordelijke');

    return {
      id,
      firstName:
        value.firstName === undefined
          ? undefined
          : this.normalizeRequiredText(value.firstName, {
              fieldName: 'Voornaam externe verantwoordelijke',
            }),
      lastName:
        value.lastName === undefined
          ? undefined
          : this.normalizeRequiredText(value.lastName, {
              fieldName: 'Achternaam externe verantwoordelijke',
            }),
      email: this.normalizeOptionalEmail(value.email),
    };
  }

  private normalizeRequiredDate(
    value: string | null | undefined,
    { fieldName }: { fieldName: string },
  ) {
    const normalizedValue = this.normalizeDate(value, { fieldName });
    if (!normalizedValue) {
      throw new BadRequestException(`${fieldName} is verplicht`);
    }

    return normalizedValue;
  }

  private normalizeActionType(value?: string | null): NormalizedActionType {
    const normalizedValue = value?.trim().toLowerCase();

    if (normalizedValue === 'corrective') {
      return 'corrective';
    }
    if (normalizedValue === 'preventive') {
      return 'preventive';
    }

    throw new BadRequestException(
      'Type opvolgactie moet corrective of preventive zijn',
    );
  }

  private normalizeActionStatus(
    value: string | null | undefined,
    { fieldName }: { fieldName: string },
  ): NormalizedActionStatus {
    const normalizedValue = value?.trim().toLowerCase();
    if (normalizedValue === 'ok') {
      return 'ok';
    }
    if (normalizedValue === 'nok') {
      return 'nok';
    }

    throw new BadRequestException(`${fieldName} moet OK of NOK zijn`);
  }

  private normalizeAssigneeType(
    value?: string | null,
  ): NormalizedAssigneeType {
    const normalizedValue = value?.trim().toLowerCase();
    if (normalizedValue === 'internal') {
      return 'internal';
    }
    if (normalizedValue === 'external') {
      return 'external';
    }

    throw new BadRequestException(
      'Verantwoordelijke moet internal of external zijn',
    );
  }

  private normalizeOptionalId(value: number | undefined, fieldName: string) {
    if (value === undefined) {
      return undefined;
    }

    return this.normalizeRequiredId(value, fieldName);
  }

  private normalizeRequiredId(value: number | null | undefined, fieldName: string) {
    if (!Number.isInteger(value) || Number(value) <= 0) {
      throw new BadRequestException(`${fieldName} is ongeldig`);
    }

    return Number(value);
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
      causeAnalysisMethod: ticket.causeAnalysisMethod,
      causeAnalysisNotes: ticket.causeAnalysisNotes,
      followUpActions: ticket.followUpActions,
      effectivenessDate: ticket.effectivenessDate?.toISOString() ?? null,
      effectivenessNotes: ticket.effectivenessNotes,
      closureNotes: ticket.closureNotes,
      closedAt: ticket.closedAt?.toISOString() ?? null,
      createdAt: ticket.createdAt.toISOString(),
      updatedAt: ticket.updatedAt.toISOString(),
      createdBy: ticket.createdBy,
      lastEditedBy: ticket.lastEditedBy,
      closedBy: ticket.closedBy,
      actions: ticket.actions.map((action) => this.serializeAction(action)),
    };
  }

  private serializeAction(action: OvaActionRecord) {
    return {
      id: action.id,
      type: action.type,
      description: action.description,
      dueDate: action.dueDate.toISOString(),
      status: action.status,
      assigneeType: action.assigneeType,
      internalAssignee: action.internalAssignee,
      externalResponsible: action.externalContact
        ? this.serializeExternalContact(action.externalContact)
        : null,
      createdAt: action.createdAt.toISOString(),
      updatedAt: action.updatedAt.toISOString(),
    };
  }

  private serializeAssignedAction(action: AssignedActionRecord) {
    return {
      ...this.serializeAction(action),
      ticket: {
        id: action.ticket.id,
        status: action.ticket.status,
        currentStep: action.ticket.currentStep,
        findingDate: action.ticket.findingDate?.toISOString() ?? null,
        ovaType: action.ticket.ovaType,
      },
    };
  }

  private serializeAssignableUser(user: AssignableOvaUser) {
    return {
      id: user.id,
      email: user.email,
      name: user.name,
    };
  }

  private serializeExternalContact(contact: {
    id: number;
    firstName: string;
    lastName: string;
    email: string | null;
  }) {
    return {
      id: contact.id,
      firstName: contact.firstName,
      lastName: contact.lastName,
      email: contact.email,
    };
  }
}
