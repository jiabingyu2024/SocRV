#include <rtthread.h>

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "drv_i2c.h"
#include "drv_oled.h"

#define OLED_WIDTH 128u
#define OLED_HEIGHT 64u
#define OLED_PAGES (OLED_HEIGHT / 8u)
#define OLED_FRAMEBUFFER_SIZE (OLED_WIDTH * OLED_PAGES)
#define OLED_COMMAND_CONTROL 0x00u
#define OLED_DATA_CONTROL 0x40u
#define OLED_DISPLAY_OFF 0xaeu
#define OLED_DISPLAY_ON 0xafu
#define OLED_CHUNK_SIZE 16u

static uint8_t framebuffer[OLED_FRAMEBUFFER_SIZE];
static uint8_t detected_address;
static rt_bool_t running;

static int oled_write_commands(const uint8_t *commands, size_t count)
{
    uint8_t buffer[32];

    if (count + 1u > sizeof(buffer)) {
        return I2C_ERR_INVALID;
    }
    buffer[0] = OLED_COMMAND_CONTROL;
    memcpy(&buffer[1], commands, count);
    return i2c_master_write(detected_address, buffer, count + 1u);
}

static int detect_address(void)
{
    static const uint8_t candidates[] = {0x3cu, 0x3du};
    size_t index;
    int result = OLED_ERR_NOT_FOUND;

    if (detected_address != 0u) {
        result = i2c_master_probe(detected_address);
        if (result == I2C_OK) {
            return I2C_OK;
        }
        detected_address = 0u;
    }

    for (index = 0u; index < sizeof(candidates); ++index) {
        result = i2c_master_probe(candidates[index]);
        if (result == I2C_OK) {
            detected_address = candidates[index];
            return I2C_OK;
        }
    }
    return result == I2C_ERR_ADDR_NACK ? OLED_ERR_NOT_FOUND : result;
}

static int initialize_ssd1306(void)
{
    static const uint8_t init_commands[] = {
        OLED_DISPLAY_OFF,
        0xd5u, 0x80u,
        0xa8u, 0x3fu,
        0xd3u, 0x00u,
        0x40u,
        0x8du, 0x14u,
        0x20u, 0x00u,
        0xa1u,
        0xc8u,
        0xdau, 0x12u,
        0x81u, 0x7fu,
        0xd9u, 0xf1u,
        0xdbu, 0x40u,
        0xa4u,
        0xa6u
    };

    return oled_write_commands(init_commands, sizeof(init_commands));
}

static void set_pixel(uint32_t x, uint32_t y)
{
    if (x < OLED_WIDTH && y < OLED_HEIGHT) {
        framebuffer[(y / 8u) * OLED_WIDTH + x] |=
            (uint8_t)(1u << (y & 7u));
    }
}

static void glyph_for(char character, uint8_t glyph[5])
{
    switch (character) {
    case 'R': {
        const uint8_t value[5] = {0x7fu, 0x09u, 0x19u, 0x29u, 0x46u};
        memcpy(glyph, value, sizeof(value));
        break;
    }
    case 'T': {
        const uint8_t value[5] = {0x01u, 0x01u, 0x7fu, 0x01u, 0x01u};
        memcpy(glyph, value, sizeof(value));
        break;
    }
    case 'h': {
        const uint8_t value[5] = {0x7fu, 0x08u, 0x08u, 0x08u, 0x70u};
        memcpy(glyph, value, sizeof(value));
        break;
    }
    case 'r': {
        const uint8_t value[5] = {0x7cu, 0x08u, 0x04u, 0x04u, 0x08u};
        memcpy(glyph, value, sizeof(value));
        break;
    }
    case 'e': {
        const uint8_t value[5] = {0x38u, 0x54u, 0x54u, 0x54u, 0x18u};
        memcpy(glyph, value, sizeof(value));
        break;
    }
    case 'a': {
        const uint8_t value[5] = {0x20u, 0x54u, 0x54u, 0x54u, 0x78u};
        memcpy(glyph, value, sizeof(value));
        break;
    }
    case 'd': {
        const uint8_t value[5] = {0x38u, 0x44u, 0x44u, 0x48u, 0x7fu};
        memcpy(glyph, value, sizeof(value));
        break;
    }
    default:
        memset(glyph, 0, 5u);
        break;
    }
}

static void draw_scaled_text(const char *text, uint32_t x, uint32_t y)
{
    uint8_t glyph[5];
    uint32_t character_index;
    uint32_t column;
    uint32_t row;
    uint32_t scale_x;
    uint32_t scale_y;

    for (character_index = 0u; text[character_index] != '\0';
         ++character_index) {
        glyph_for(text[character_index], glyph);
        for (column = 0u; column < 5u; ++column) {
            for (row = 0u; row < 7u; ++row) {
                if ((glyph[column] & (1u << row)) != 0u) {
                    for (scale_x = 0u; scale_x < 2u; ++scale_x) {
                        for (scale_y = 0u; scale_y < 2u; ++scale_y) {
                            set_pixel(
                                x + character_index * 12u + column * 2u + scale_x,
                                y + row * 2u + scale_y
                            );
                        }
                    }
                }
            }
        }
    }
}

static int refresh_framebuffer(void)
{
    static const uint8_t window_commands[] = {
        0x21u, 0x00u, 0x7fu,
        0x22u, 0x00u, 0x07u
    };
    uint8_t buffer[OLED_CHUNK_SIZE + 1u];
    size_t offset;
    size_t chunk;
    int result;

    result = oled_write_commands(window_commands, sizeof(window_commands));
    for (offset = 0u; result == I2C_OK && offset < sizeof(framebuffer);
         offset += chunk) {
        chunk = sizeof(framebuffer) - offset;
        if (chunk > OLED_CHUNK_SIZE) {
            chunk = OLED_CHUNK_SIZE;
        }
        buffer[0] = OLED_DATA_CONTROL;
        memcpy(&buffer[1], &framebuffer[offset], chunk);
        result = i2c_master_write(detected_address, buffer, chunk + 1u);
    }
    return result;
}

int oled_start_rtthread(void)
{
    const uint8_t display_on = OLED_DISPLAY_ON;
    int result;

    if (running) {
        return OLED_ALREADY_RUNNING;
    }
    result = detect_address();
    if (result != I2C_OK) {
        return result;
    }
    result = initialize_ssd1306();
    if (result != I2C_OK) {
        return result;
    }

    memset(framebuffer, 0, sizeof(framebuffer));
    draw_scaled_text("RTThread", 16u, 25u);
    result = refresh_framebuffer();
    if (result == I2C_OK) {
        result = oled_write_commands(&display_on, 1u);
    }
    if (result == I2C_OK) {
        running = RT_TRUE;
    }
    return result;
}

int oled_stop(void)
{
    const uint8_t display_off = OLED_DISPLAY_OFF;
    int result;

    if (!running) {
        return OLED_ALREADY_STOPPED;
    }
    result = oled_write_commands(&display_off, 1u);
    if (result == I2C_OK) {
        running = RT_FALSE;
    }
    return result;
}

uint8_t oled_address(void)
{
    return detected_address;
}

int oled_is_running(void)
{
    return running ? 1 : 0;
}

const char *oled_controller_name(void)
{
    return "ssd1306";
}
