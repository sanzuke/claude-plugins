import { expect, test } from '../fixtures';

// Judul test HARUS identik dengan nama test case di Huly Test Management —
// itu satu-satunya jembatan saat hasil run dilaporkan lewat huly_set_test_result.
test.describe('Login', () => {
  test('Anggota dengan kredensial valid bisa masuk ke dashboard', async ({ loginPage, page }) => {
    await loginPage.goto();
    await loginPage.login('anggota@contoh.id', 'rahasia123');

    // Web-first assertion: otomatis retry sampai timeout. Jangan pakai waitForTimeout.
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('Login dengan kata sandi salah menampilkan pesan error', async ({ loginPage }) => {
    await loginPage.goto();
    await loginPage.login('anggota@contoh.id', 'salah');

    await expect(loginPage.errorAlert).toHaveText('Email atau kata sandi salah');
  });
});
