import { test as base, expect } from '@playwright/test';

import { LoginPage } from './pages/login.page';

type Pages = {
  loginPage: LoginPage;
};

// Semua spec import dari file ini, bukan langsung dari @playwright/test.
// Page object baru didaftarkan di sini supaya spec tidak perlu `new` sendiri.
export const test = base.extend<Pages>({
  loginPage: async ({ page }, use) => {
    await use(new LoginPage(page));
  },
});

export { expect };
