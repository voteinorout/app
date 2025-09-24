import { jest } from '@jest/globals';

let handler;
let mockCreate;

beforeAll(async () => {
  mockCreate = jest.fn().mockResolvedValue({
    choices: [
      {
        message: {
          content: 'mocked script content',
        },
      },
    ],
  });

  await jest.unstable_mockModule('openai', () => ({
    default: jest.fn().mockImplementation(() => ({
      chat: {
        completions: {
          create: mockCreate,
        },
      },
    })),
  }));

  ({ default: handler } = await import('../generate-script.js'));
});

beforeEach(() => {
  jest.clearAllMocks();
});

function createMockRes() {
  return {
    statusCode: null,
    payload: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(data) {
      this.payload = data;
      return this;
    },
  };
}

test('returns 405 for non-POST requests', async () => {
  const req = { method: 'GET', body: {} };
  const res = createMockRes();

  await handler(req, res);

  expect(res.statusCode).toBe(405);
  expect(res.payload).toEqual({ error: 'Method not allowed' });
  expect(mockCreate).not.toHaveBeenCalled();
});

test('proxies script generation to OpenAI and returns text', async () => {
  const req = {
    method: 'POST',
    body: {
      topic: 'civic duty',
      length: 30,
      style: 'Educational',
      searchFacts: ['fact 1'],
    },
  };
  const res = createMockRes();

  await handler(req, res);

  expect(mockCreate).toHaveBeenCalledTimes(1);
  expect(res.statusCode).toBe(200);
  expect(res.payload).toEqual({ text: 'mocked script content' });
});
