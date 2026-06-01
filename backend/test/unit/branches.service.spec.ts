import { BranchesService } from '../../src/branches/branches.service';

describe('BranchesService', () => {
  it('creates a new branch without department links when none are provided', async () => {
    const prisma = {
      branch: {
        create: jest.fn().mockResolvedValue({
          id: 7,
          name: 'Nieuwe vestiging',
          createdAt: new Date('2026-06-01T00:00:00.000Z'),
          departments: [],
        }),
      },
      department: {
        count: jest.fn(),
      },
    };
    const service = new BranchesService(prisma as any);

    await expect(service.create({ name: 'Nieuwe vestiging' })).resolves.toEqual(
      expect.objectContaining({
        id: 7,
        name: 'Nieuwe vestiging',
        departmentIds: [],
        departments: [],
      }),
    );

    expect(prisma.department.count).not.toHaveBeenCalled();
    expect(prisma.branch.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: {
          name: 'Nieuwe vestiging',
          departments: {
            create: [],
          },
        },
      }),
    );
  });

  it('keeps explicitly provided department links when creating a branch', async () => {
    const prisma = {
      branch: {
        create: jest.fn().mockResolvedValue({
          id: 8,
          name: 'Gekoppelde vestiging',
          createdAt: new Date('2026-06-01T00:00:00.000Z'),
          departments: [
            { department: { id: 3, name: 'Logistiek' } },
            { department: { id: 5, name: 'Techniek' } },
          ],
        }),
      },
      department: {
        count: jest.fn().mockResolvedValue(2),
      },
    };
    const service = new BranchesService(prisma as any);

    await expect(
      service.create({
        name: 'Gekoppelde vestiging',
        departmentIds: [3, 5],
      }),
    ).resolves.toEqual(
      expect.objectContaining({
        id: 8,
        departmentIds: [3, 5],
      }),
    );

    expect(prisma.department.count).toHaveBeenCalledWith({
      where: {
        id: {
          in: [3, 5],
        },
      },
    });
    expect(prisma.branch.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: {
          name: 'Gekoppelde vestiging',
          departments: {
            create: [{ departmentId: 3 }, { departmentId: 5 }],
          },
        },
      }),
    );
  });
});
