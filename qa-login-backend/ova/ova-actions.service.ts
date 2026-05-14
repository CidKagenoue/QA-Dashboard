// qa-login-backend/src/ova/ova-actions.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class OvaActionsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Haalt alle OvaFollowUpActions op die als interne verantwoordelijke
   * de opgegeven gebruiker hebben, inclusief ticket-info.
   */
  async findByAssignee(userId: number) {
    const actions = await this.prisma.ovaFollowUpAction.findMany({
      where: {
        internalAssigneeId: userId,
        // Alleen acties van tickets die nog niet gesloten zijn
        ticket: {
          status: { notIn: ['closed', 'completed'] },
        },
      },
      include: {
        ticket: {
          select: {
            id: true,
            status: true,
            currentStep: true,
            findingDate: true,
            ovaType: true,
          },
        },
        internalAssignee: {
          select: { id: true, email: true, name: true },
        },
        externalContact: {
          select: { id: true, firstName: true, lastName: true, email: true },
        },
      },
      orderBy: { dueDate: 'asc' },
    });

    // Zet om naar het formaat dat de Flutter app verwacht
    return actions.map((a) => ({
      id: a.id,
      type: a.type,
      description: a.description,
      dueDate: a.dueDate.toISOString(),
      status: a.status,
      assigneeType: a.assigneeType,
      createdAt: a.createdAt.toISOString(),
      updatedAt: a.updatedAt.toISOString(),
      internalAssignee: a.internalAssignee
        ? {
            id: a.internalAssignee.id,
            email: a.internalAssignee.email,
            name: a.internalAssignee.name,
          }
        : null,
      externalResponsible: a.externalContact
        ? {
            id: a.externalContact.id,
            firstName: a.externalContact.firstName,
            lastName: a.externalContact.lastName,
            email: a.externalContact.email,
          }
        : null,
      // Ticket-samenvatting die OvaAssignedAction.fromJson verwacht
      ticket: {
        id: a.ticket.id,
        status: a.ticket.status,
        currentStep: a.ticket.currentStep,
        findingDate: a.ticket.findingDate?.toISOString() ?? null,
        ovaType: a.ticket.ovaType ?? null,
      },
    }));
  }

  /**
   * Werkt een actie bij (enkel status voor nu).
   */
  async updateAction(id: number, data: { status?: string }) {
    const existing = await this.prisma.ovaFollowUpAction.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException(`Actie #${id} niet gevonden`);

    const updated = await this.prisma.ovaFollowUpAction.update({
      where: { id },
      data: { status: data.status ?? existing.status },
      include: {
        internalAssignee: {
          select: { id: true, email: true, name: true },
        },
        externalContact: {
          select: { id: true, firstName: true, lastName: true, email: true },
        },
        ticket: {
          select: {
            id: true,
            status: true,
            currentStep: true,
            findingDate: true,
            ovaType: true,
          },
        },
      },
    });

    return {
      id: updated.id,
      type: updated.type,
      description: updated.description,
      dueDate: updated.dueDate.toISOString(),
      status: updated.status,
      assigneeType: updated.assigneeType,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
      internalAssignee: updated.internalAssignee
        ? {
            id: updated.internalAssignee.id,
            email: updated.internalAssignee.email,
            name: updated.internalAssignee.name,
          }
        : null,
      externalResponsible: updated.externalContact
        ? {
            id: updated.externalContact.id,
            firstName: updated.externalContact.firstName,
            lastName: updated.externalContact.lastName,
            email: updated.externalContact.email,
          }
        : null,
      ticket: {
        id: updated.ticket.id,
        status: updated.ticket.status,
        currentStep: updated.ticket.currentStep,
        findingDate: updated.ticket.findingDate?.toISOString() ?? null,
        ovaType: updated.ticket.ovaType ?? null,
      },
    };
  }
}