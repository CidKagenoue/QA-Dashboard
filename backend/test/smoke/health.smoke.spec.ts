/*
Testtype: Smoke test
Omschrijving: Korte sanity-check of de app boot en `/health` endpoint werken.
*/
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppController } from '../../src/app.controller';
import { createTestApp, closeTestApp } from '../utils/test-utils';

describe('Health (smoke)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createTestApp([AppController]);
  });

  afterAll(async () => {
    await closeTestApp(app);
  });

  it('/health (GET) should return status ok', async () => {
    const res = await request(app.getHttpServer()).get('/health').expect(200);
    expect(res.body).toHaveProperty('status', 'ok');
  });
});
