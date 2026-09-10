import type { Locator, Page } from '@playwright/test';

/**
 * Page object = locator + aksi. TIDAK ada assertion di sini.
 * Locator dibuat sekali di constructor, pakai peran/label — bukan CSS berantai.
 */
export class LoginPage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorAlert: Locator;

  constructor(private readonly page: Page) {
    this.emailInput = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Kata sandi');
    this.submitButton = page.getByRole('button', { name: 'Masuk' });
    this.errorAlert = page.getByRole('alert');
  }

  async goto(): Promise<void> {
    await this.page.goto('/login');
  }

  async login(email: string, password: string): Promise<void> {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
