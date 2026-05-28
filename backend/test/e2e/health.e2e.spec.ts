/*
Testtype: E2E test
Omschrijving: Controleert de publieke API-basis, zodat deze test meer de
             volledige app-werking afdekt dan de smoke-test.
*/
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppController } from '../../src/app.controller';
import { createTestApp, closeTestApp } from '../utils/test-utils';

describe('Health (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createTestApp([AppController]);
  });

  afterAll(async () => {
    await closeTestApp(app);
  });

  it('GET / should return API info', async () => {
    const res = await request(app.getHttpServer()).get('/').expect(200);
    expect(res.body).toHaveProperty('message', 'QA Dashboard API draait');
    expect(res.body).toHaveProperty('version', '1.0.0');
    expect(res.body).toHaveProperty('endpoints');
  });

  it('/health (GET) should return status ok', async () => {
    const res = await request(app.getHttpServer()).get('/health').expect(200);
    expect(res.body).toHaveProperty('status', 'ok');
  });
});
