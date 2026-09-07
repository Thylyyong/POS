import 'dotenv/config';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import { z } from 'zod';

const config = {
  host: process.env.HOST ?? '127.0.0.1',
  port: Number(process.env.PORT ?? 8080),
  allowedOrigins: (process.env.ALLOWED_ORIGINS ?? '').split(',').map((value) => value.trim()).filter(Boolean),
  abaWebhookSecret: process.env.ABA_WEBHOOK_SECRET ?? '',
};

const app = Fastify({ logger: { redact: ['req.headers.authorization', 'req.headers.cookie'] } });
const payments = new Map<string, Payment>();
const idempotency = new Map<string, string>();

type PaymentStatus = 'PENDING' | 'SETTLED' | 'FAILED' | 'EXPIRED' | 'REFUNDED';
type Payment = {
  id: string;
  orderId: string;
  branchId: string;
  amountMinor: number;
  currency: string;
  status: PaymentStatus;
  providerTransactionId?: string;
  createdAt: string;
};

const createPaymentSchema = z.object({
  orderId: z.string().min(1).max(100),
  branchId: z.string().min(1).max(100),
  amountMinor: z.number().int().positive(),
  currency: z.string().length(3).regex(/^[A-Z]{3}$/),
});

await app.register(helmet);
await app.register(cors, {
  origin: config.allowedOrigins.length > 0 ? config.allowedOrigins : false,
});

app.get('/health', async () => ({ status: 'ok' }));

app.post('/v1/payments/aba', async (request, reply) => {
  const idempotencyKey = request.headers['idempotency-key'];
  if (typeof idempotencyKey !== 'string' || idempotencyKey.length < 16 || idempotencyKey.length > 200) {
    return reply.code(400).send({ error: 'A valid Idempotency-Key header is required.' });
  }

  const parsed = createPaymentSchema.safeParse(request.body);
  if (!parsed.success) return reply.code(400).send({ error: 'Invalid payment request.' });

  const existingId = idempotency.get(idempotencyKey);
  if (existingId) return reply.send(publicPayment(payments.get(existingId)!));

  return reply.code(503).send({
    error: 'ABA integration is not configured.',
    detail: 'Configure the official ABA sandbox adapter before creating real payments.',
  });
});

app.get('/v1/payments/:paymentId', async (request, reply) => {
  const params = z.object({ paymentId: z.string().uuid() }).safeParse(request.params);
  if (!params.success) return reply.code(400).send({ error: 'Invalid payment ID.' });

  const payment = payments.get(params.data.paymentId);
  if (!payment) return reply.code(404).send({ error: 'Payment not found.' });
  return reply.send(publicPayment(payment));
});

app.post('/v1/webhooks/aba', async (request, reply) => {
  // Do not accept callbacks until ABA's exact raw-body signature contract is configured.
  if (!config.abaWebhookSecret) {
    return reply.code(503).send({ error: 'ABA webhook integration is not configured.' });
  }
  const signature = request.headers['x-aba-signature'];
  if (typeof signature !== 'string' || signature.length === 0) {
    return reply.code(401).send({ error: 'Invalid webhook signature.' });
  }
  return reply.code(501).send({ error: 'ABA webhook adapter is not configured.' });
});

function publicPayment(payment: Payment | undefined) {
  if (!payment) return { error: 'Payment not found.' };
  return {
    id: payment.id,
    orderId: payment.orderId,
    status: payment.status,
    currency: payment.currency,
    amountMinor: payment.amountMinor,
    providerTransactionId: payment.providerTransactionId,
    createdAt: payment.createdAt,
  };
}

app.setErrorHandler((error, _request, reply) => {
  app.log.error(error);
  return reply.code(500).send({ error: 'Internal server error.' });
});

try {
  await app.listen({ host: config.host, port: config.port });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}
