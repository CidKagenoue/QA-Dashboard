import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';

// Helper voor tests: bouwt en initialiseert een minimale Nest test-app
export async function createTestApp(controllers: any[]): Promise<INestApplication> {
  const moduleFixture: TestingModule = await Test.createTestingModule({ controllers }).compile();
  const app = moduleFixture.createNestApplication();
  await app.init();
  return app;
}

export async function closeTestApp(app: INestApplication) {
  if (app) await app.close();
}
