import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().port().default(5400),

  DATABASE_URL: Joi.string()
    .uri({ scheme: ['postgresql', 'postgres'] })
    .required(),
  REDIS_URL: Joi.string().uri({ scheme: ['redis'] }).default('redis://127.0.0.1:6380'),

  JWT_ACCESS_SECRET: Joi.string().min(32).required(),
  JWT_REFRESH_SECRET: Joi.string().min(32).required(),
  JWT_ACCESS_TTL: Joi.string().default('15m'),
  JWT_REFRESH_TTL: Joi.string().default('7d'),

  BCRYPT_ROUNDS: Joi.number().integer().min(4).max(15).default(12),

  SEED_ADMIN_EMAIL: Joi.string().email({ tlds: { allow: false } }).required(),
  SEED_ADMIN_PASSWORD: Joi.string().min(8).required(),

  CORS_ORIGINS: Joi.string().default('http://localhost:8080'),
  THROTTLE_TTL: Joi.number().integer().min(1000).default(60000),
  THROTTLE_LIMIT: Joi.number().integer().min(1).default(60),
});
