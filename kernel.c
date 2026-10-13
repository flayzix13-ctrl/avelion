/* MyOS Kernel v2.3 — VBE 1024x768x32, читаем W/H/stride */

static int W = 1024;   /* заполняется из VBE */
static int H = 768;
static unsigned int  lfb_addr   = 0;
static unsigned int  lfb_stride = 1024;

extern void irq12_stub(void);
extern void irq_default_stub(void);
void irq12_handler(void);
void irq_default_handler(void);

/* ============ ПОРТЫ ============ */
static inline void outb(unsigned short port, unsigned char val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}
static inline unsigned char inb(unsigned short port) {
    unsigned char v;
    __asm__ volatile ("inb %1, %0" : "=a"(v) : "Nd"(port));
    return v;
}
static inline void io_wait(void) { outb(0x80, 0); }

/* ============ ЦВЕТА ============ */
#define C_BLACK      0x00000000
#define C_WHITE      0x00FFFFFF
#define C_PANEL      0x00202426
#define C_MINT       0x0056A587
#define C_MINT_LIGHT 0x0071CC2E
#define C_GREY       0x00C0C0C0
#define C_DARKGREY   0x00404040
#define C_GREEN      0x0071CC2E
#define C_YELLOW     0x000FC4F1
#define C_ORANGE     0x0023A5F1
#define C_RED        0x003C4CE7
#define C_SKY        0x00F1D5A5

/* ============ РИСОВАНИЕ ============ */
static void fill_rect(int x, int y, int w, int h, unsigned int color) {
    if (w <= 0 || h <= 0) return;
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > W) w = W - x;
    if (y + h > H) h = H - y;
    if (w <= 0 || h <= 0) return;

    unsigned int *lfb = (unsigned int *)lfb_addr;
    for (int row = y; row < y + h; row++) {
        unsigned int *line = lfb + row * lfb_stride + x;
        for (int i = 0; i < w; i++) line[i] = color;
    }
}

/* ============ ШРИФТ 5x7 ============ */
typedef struct { char ch; unsigned char rows[7]; } Glyph;

static const Glyph font[] = {
    {' ', { 0, 0, 0, 0, 0, 0, 0}},
    {'M', {17,27,21,17,17,17,17}},
    {'y', { 0, 0,17,17,15, 1,14}},
    {'O', {14,17,17,17,17,17,14}},
    {'S', {15,16,16,14, 1, 1,30}},
    {'t', { 4, 4,31, 4, 4, 3, 0}},
    {'a', { 0, 0,14, 1,15,17,15}},
    {'r', { 0, 0,22,25,16,16,16}},
    {'C', {15,16,16,16,16,16,15}},
    {'o', { 0, 0,14,17,17,17,14}},
    {'m', { 0, 0,26,21,21,21,21}},
    {'p', { 0, 0,30,17,30,16,16}},
    {'u', { 0, 0,17,17,17,19,13}},
    {'e', { 0, 0,14,17,31,16,15}},
    {'F', {31,16,16,30,16,16,16}},
    {'i', { 4, 0, 4, 4, 4, 4, 4}},
    {'l', { 6, 4, 4, 4, 4, 4,14}},
    {'T', {31, 4, 4, 4, 4, 4, 4}},
    {'n', { 0, 0,22,25,17,17,17}},
    {'s', { 0, 0,15,16,14, 1,30}},
    {'D', {30,17,17,17,17,17,30}},
    {'k', {16,16,18,20,24,20,18}},
    {'P', {30,17,17,30,16,16,16}},
    {':', { 0, 4, 4, 0, 4, 4, 0}},
    {'0', {14,17,19,21,25,17,14}},
    {'1', { 4,12, 4, 4, 4, 4,14}},
    {'2', {14,17, 1, 6, 8,16,31}},
    {'3', {31, 2, 4, 2, 1,17,14}},
    {'4', { 2, 6,10,18,31, 2, 2}},
    {'5', {31,16,30, 1, 1,17,14}},
    {'6', { 6, 8,16,30,17,17,14}},
    {'7', {31, 1, 2, 4, 8, 8, 8}},
    {'8', {14,17,17,14,17,17,14}},
    {'9', {14,17,17,15, 1, 2,12}},
    {0,   { 0, 0, 0, 0, 0, 0, 0}}
};

static const unsigned char *glyph(char ch) {
    for (int i = 0; font[i].ch; i++)
        if (font[i].ch == ch) return font[i].rows;
    return font[0].rows;
}

static void draw_char(int x, int y, char ch, unsigned int color, int scale) {
    const unsigned char *g = glyph(ch);
    for (int r = 0; r < 7; r++) {
        unsigned char bits = g[r];
        for (int col = 0; col < 5; col++) {
            if (bits & (16 >> col)) {
                fill_rect(x + col*scale, y + r*scale, scale, scale, color);
            }
        }
    }
}

static void draw_text(int x, int y, const char *s, unsigned int color, int scale) {
    while (*s) {
        draw_char(x, y, *s, color, scale);
        x += (5 + 1) * scale;
        s++;
    }
}

/* ============ ИКОНКИ ============ */
static void draw_icon_computer(int x, int y) {
    fill_rect(x + 8,  y + 4,  48, 34, C_WHITE);
    fill_rect(x + 12, y + 8,  40, 26, C_SKY);
    fill_rect(x + 14, y + 10, 12,  4, C_WHITE);
    fill_rect(x + 28, y + 38,  8, 10, C_WHITE);
    fill_rect(x + 12, y + 48, 40,  4, C_WHITE);
    fill_rect(x + 6,  y + 52, 52,  3, C_WHITE);
}

static void draw_icon_files(int x, int y) {
    fill_rect(x + 4,  y + 12, 56, 40, C_ORANGE);
    fill_rect(x + 4,  y + 6,  22, 10, C_ORANGE);
    fill_rect(x + 8,  y + 20, 48, 28, 0x00E07000);
    fill_rect(x + 6,  y + 14, 20,  4, C_YELLOW);
}

static void draw_icon_term(int x, int y) {
    fill_rect(x + 4,  y + 4,  56, 56, C_WHITE);
    fill_rect(x + 6,  y + 6,  52, 52, C_BLACK);
    fill_rect(x + 12, y + 16,  4,  4, C_GREEN);
    fill_rect(x + 16, y + 20,  4,  4, C_GREEN);
    fill_rect(x + 20, y + 24,  4,  4, C_GREEN);
    fill_rect(x + 16, y + 28,  4,  4, C_GREEN);
    fill_rect(x + 12, y + 32,  4,  4, C_GREEN);
    fill_rect(x + 28, y + 44, 20,  4, C_WHITE);
}

static void draw_icon_set(int x, int y) {
    fill_rect(x + 16, y + 4,  32, 56, C_GREY);
    fill_rect(x + 8,  y + 12, 48, 40, C_GREY);
    fill_rect(x + 4,  y + 20, 56, 24, C_GREY);
    fill_rect(x + 24, y + 20, 16, 24, C_DARKGREY);
    fill_rect(x + 20, y + 24, 24, 16, C_DARKGREY);
    fill_rect(x + 28, y + 28,  8,  8, C_MINT);
}

/* ============ РАБОЧИЙ СТОЛ ============ */
static void draw_desktop(void) {
    /* 1. Заливаем ВЕСЬ stride по ВСЕЙ высоте — никаких чёрных полос */
    unsigned int *lfb = (unsigned int *)lfb_addr;
    for (int y = 0; y < H; y++) {
        int r = 0x22 + (0x0A - 0x22) * y / H;
        int g = 0x2E + (0x12 - 0x2E) * y / H;
        int b = 0x22 + (0x0E - 0x22) * y / H;
        unsigned int color = (r << 16) | (g << 8) | b;
        unsigned int *line = lfb + y * lfb_stride;
        /* заливаем весь stride — включая padding справа */
        for (int x = 0; x < (int)lfb_stride; x++) line[x] = color;
    }

    /* 2. Иконки */
    draw_icon_computer(40, 40);
    draw_text(48, 120, "MyPC", C_WHITE, 2);

    draw_icon_files(40, 180);
    draw_text(48, 260, "Files", C_WHITE, 2);

    draw_icon_term(40, 320);
    draw_text(48, 400, "Term", C_WHITE, 2);

    draw_icon_set(40, 460);
    draw_text(48, 540, "Set", C_WHITE, 2);

    /* 3. Панель задач снизу (прижата к H) */
    fill_rect(0, H - 48, W, 48, C_PANEL);
    fill_rect(0, H - 48, W, 1, 0x00404040);

    fill_rect(16, H - 40, 120, 32, C_MINT);
    fill_rect(16, H - 40, 120, 2, C_MINT_LIGHT);
    draw_text(38, H - 32, "Menu", C_WHITE, 2);

    draw_text(W - 100, H - 32, "12:00", C_WHITE, 2);

    fill_rect(W - 60, H - 36, 20, 20, C_DARKGREY);
    fill_rect(W - 32, H - 36, 20, 20, C_DARKGREY);
    fill_rect(W - 88, H - 36, 20, 20, C_DARKGREY);

    /* 4. Заголовок по центру */
    draw_text(W/2 - 90, 24, "MyOS Desktop", C_WHITE, 3);
}

/* ============ КУРСОР ============ */
static const unsigned char cursor[12][8] = {
    {1,0,0,0,0,0,0,0},
    {1,1,0,0,0,0,0,0},
    {1,2,1,0,0,0,0,0},
    {1,2,2,1,0,0,0,0},
    {1,2,2,2,1,0,0,0},
    {1,2,2,2,2,1,0,0},
    {1,2,2,2,2,2,1,0},
    {1,2,2,2,2,2,2,1},
    {1,2,2,2,1,1,1,0},
    {1,2,1,2,1,0,0,0},
    {1,1,0,1,2,1,0,0},
    {1,0,0,0,1,2,1,0}
};

static int cx = 512;
static int cy = 384;
static unsigned int save_buf[12][8];

static void draw_cursor(int x, int y) {
    unsigned int *lfb = (unsigned int *)lfb_addr;
    for (int r = 0; r < 12; r++)
        for (int c = 0; c < 8; c++) {
            unsigned char v = cursor[r][c];
            if (!v) continue;
            int px = x + c, py = y + r;
            if (px < 0 || px >= W || py < 0 || py >= H) continue;
            lfb[py * lfb_stride + px] = (v == 1) ? C_WHITE : C_BLACK;
        }
}

static void cursor_save(int x, int y) {
    unsigned int *lfb = (unsigned int *)lfb_addr;
    for (int r = 0; r < 12; r++)
        for (int c = 0; c < 8; c++) {
            int px = x + c, py = y + r;
            save_buf[r][c] = (px >= 0 && px < W && py >= 0 && py < H)
                             ? lfb[py * lfb_stride + px] : 0;
        }
}

static void cursor_restore(int x, int y) {
    unsigned int *lfb = (unsigned int *)lfb_addr;
    for (int r = 0; r < 12; r++)
        for (int c = 0; c < 8; c++) {
            int px = x + c, py = y + r;
            if (px >= 0 && px < W && py >= 0 && py < H)
                lfb[py * lfb_stride + px] = save_buf[r][c];
        }
}

/* ============ IDT ============ */
struct idt_entry {
    unsigned short offset_lo;
    unsigned short selector;
    unsigned char  zero;
    unsigned char  flags;
    unsigned short offset_hi;
} __attribute__((packed));

struct idt_ptr {
    unsigned short limit;
    unsigned int   base;
} __attribute__((packed));

static struct idt_entry idt[256];
static struct idt_ptr   idtp;

static void idt_set(int n, unsigned int handler) {
    idt[n].offset_lo = handler & 0xFFFF;
    idt[n].selector  = 0x08;
    idt[n].zero      = 0;
    idt[n].flags     = 0x8E;
    idt[n].offset_hi = (handler >> 16) & 0xFFFF;
}

static void idt_load(void) {
    idtp.limit = sizeof(idt) - 1;
    idtp.base  = (unsigned int)&idt;
    __asm__ volatile ("lidt %0" : : "m"(idtp));
}

/* ============ PIC ============ */
#define PIC1_CMD  0x20
#define PIC1_DAT  0x21
#define PIC2_CMD  0xA0
#define PIC2_DAT  0xA1
#define PIC_EOI   0x20

static void pic_remap(void) {
    outb(PIC1_CMD, 0x11); io_wait();
    outb(PIC2_CMD, 0x11); io_wait();
    outb(PIC1_DAT, 0x20); io_wait();
    outb(PIC2_DAT, 0x28); io_wait();
    outb(PIC1_DAT, 0x04); io_wait();
    outb(PIC2_DAT, 0x02); io_wait();
    outb(PIC1_DAT, 0x01); io_wait();
    outb(PIC2_DAT, 0x01); io_wait();
    outb(PIC1_DAT, 0xF8);
    outb(PIC2_DAT, 0xEF);
}

static void pic_eoi(int irq) {
    if (irq >= 8) outb(PIC2_CMD, PIC_EOI);
    outb(PIC1_CMD, PIC_EOI);
}

/* ============ PS/2 МЫШЬ ============ */
static unsigned char mouse_cycle = 0;
static unsigned char mouse_byte[3];
static int mouse_dx = 0;
static int mouse_dy = 0;

static void mouse_wait_write(void) {
    int t = 100000;
    while (t--) if ((inb(0x64) & 2) == 0) return;
}
static void mouse_wait_read(void) {
    int t = 100000;
    while (t--) if (inb(0x64) & 1) return;
}
static void mouse_write(unsigned char data) {
    mouse_wait_write();
    outb(0x64, 0xD4);
    mouse_wait_write();
    outb(0x60, data);
}
static unsigned char mouse_read(void) {
    mouse_wait_read();
    return inb(0x60);
}
static void mouse_init(void) {
    mouse_wait_write();
    outb(0x64, 0xA8);
    mouse_wait_write();
    outb(0x64, 0x20);
    mouse_wait_read();
    unsigned char status = inb(0x60);
    status |= 2;
    status &= ~0x20;
    mouse_wait_write();
    outb(0x64, 0x60);
    mouse_wait_write();
    outb(0x60, status);
    mouse_write(0xFF); mouse_read(); mouse_read(); mouse_read();
    mouse_write(0xF6); mouse_read();
    mouse_write(0xF4); mouse_read();
    mouse_cycle = 0;
    mouse_dx = 0;
    mouse_dy = 0;
}

void irq12_handler(void) {
    unsigned char status = inb(0x64);
    if (!(status & 0x20)) { pic_eoi(12); return; }
    unsigned char data = inb(0x60);
    switch (mouse_cycle) {
        case 0:
            mouse_byte[0] = data;
            if (data & 0x08) mouse_cycle++;
            break;
        case 1:
            mouse_byte[1] = data;
            mouse_cycle++;
            break;
        case 2:
            mouse_byte[2] = data;
            mouse_cycle = 0;
            mouse_dx += (int)(signed char)mouse_byte[1];
            mouse_dy -= (int)(signed char)mouse_byte[2];
            break;
    }
    pic_eoi(12);
}

void irq_default_handler(void) { pic_eoi(0); }

/* ============ ГЛАВНАЯ ============ */
void kmain(void) {
    /* читаем параметры от stage2 */
    unsigned int  *p_lfb    = (unsigned int  *)0x0800;
    unsigned short *p_w      = (unsigned short *)0x0804;
    unsigned short *p_h      = (unsigned short *)0x0806;
    unsigned short *p_stride = (unsigned short *)0x0808;
    unsigned char *p_bpp     = (unsigned char  *)0x080A;

    lfb_addr = *p_lfb;

    W = *p_w;
    H = *p_h;
    if (W <= 0 || W > 4096) W = 1024;
    if (H <= 0 || H > 4096) H = 768;

    unsigned short stride_bytes = *p_stride;
    if (stride_bytes == 0) stride_bytes = W * 4;
    lfb_stride = stride_bytes / 4;

    cx = W / 2;
    cy = H / 2;

    draw_desktop();

    for (int i = 0; i < 256; i++) idt_set(i, (unsigned int)irq_default_stub);
    idt_set(0x20 + 12, (unsigned int)irq12_stub);
    idt_load();

    pic_remap();
    mouse_init();

    cursor_save(cx, cy);
    draw_cursor(cx, cy);

    __asm__ volatile ("sti");

    while (1) {
        if (mouse_dx != 0 || mouse_dy != 0) {
            int old_x = cx, old_y = cy;
            cx += mouse_dx;
            cy += mouse_dy;
            mouse_dx = 0;
            mouse_dy = 0;
            if (cx < 0) cx = 0;
            if (cy < 0) cy = 0;
            if (cx > W - 8) cx = W - 8;
            if (cy > H - 12) cy = H - 12;
            if (cx != old_x || cy != old_y) {
                cursor_restore(old_x, old_y);
                cursor_save(cx, cy);
                draw_cursor(cx, cy);
            }
        }
        __asm__ volatile ("hlt");
    }
}