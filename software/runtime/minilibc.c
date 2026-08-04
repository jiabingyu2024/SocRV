#include <stddef.h>
#include "drv_uart.h"

void *memset(void *destination, int value, size_t count)
{
    unsigned char *bytes = destination;
    while (count-- != 0u) {
        *bytes++ = (unsigned char)value;
    }
    return destination;
}

void *memcpy(void *destination, const void *source, size_t count)
{
    unsigned char *to = destination;
    const unsigned char *from = source;
    while (count-- != 0u) {
        *to++ = *from++;
    }
    return destination;
}

void *memmove(void *destination, const void *source, size_t count)
{
    unsigned char *to = destination;
    const unsigned char *from = source;
    if (to < from) {
        return memcpy(destination, source, count);
    }
    while (count-- != 0u) {
        to[count] = from[count];
    }
    return destination;
}

size_t strlen(const char *text)
{
    const char *end = text;
    while (*end != '\0') {
        ++end;
    }
    return (size_t)(end - text);
}

int memcmp(const void *left, const void *right, size_t count)
{
    const unsigned char *left_bytes = left;
    const unsigned char *right_bytes = right;
    while (count-- != 0u) {
        if (*left_bytes != *right_bytes) {
            return (int)*left_bytes - (int)*right_bytes;
        }
        ++left_bytes;
        ++right_bytes;
    }
    return 0;
}

int strcmp(const char *left, const char *right)
{
    while (*left != '\0' && *left == *right) {
        ++left;
        ++right;
    }
    return (int)(unsigned char)*left - (int)(unsigned char)*right;
}

int strncmp(const char *left, const char *right, size_t count)
{
    while (count-- != 0u) {
        unsigned char left_byte = (unsigned char)*left++;
        unsigned char right_byte = (unsigned char)*right++;
        if (left_byte != right_byte) {
            return (int)left_byte - (int)right_byte;
        }
        if (left_byte == '\0') {
            break;
        }
    }
    return 0;
}

char *strcpy(char *destination, const char *source)
{
    char *result = destination;
    do {
        *destination++ = *source;
    } while (*source++ != '\0');
    return result;
}

char *strncpy(char *destination, const char *source, size_t count)
{
    char *result = destination;
    while (count != 0u && *source != '\0') {
        *destination++ = *source++;
        --count;
    }
    while (count-- != 0u) {
        *destination++ = '\0';
    }
    return result;
}

char *strcat(char *destination, const char *source)
{
    char *result = destination;
    destination += strlen(destination);
    (void)strcpy(destination, source);
    return result;
}

char *strchr(const char *text, int character)
{
    char wanted = (char)character;
    for (;;) {
        if (*text == wanted) {
            return (char *)text;
        }
        if (*text++ == '\0') {
            return NULL;
        }
    }
}

char *strstr(const char *haystack, const char *needle)
{
    size_t needle_length = strlen(needle);
    if (needle_length == 0u) {
        return (char *)haystack;
    }
    while (*haystack != '\0') {
        if (strncmp(haystack, needle, needle_length) == 0) {
            return (char *)haystack;
        }
        ++haystack;
    }
    return NULL;
}

unsigned long strtoul(const char *text, char **end, int base)
{
    unsigned long value = 0u;
    const char *cursor = text;

    while (*cursor == ' ' || *cursor == '\t') {
        ++cursor;
    }
    if (base == 0) {
        if (cursor[0] == '0' && (cursor[1] == 'x' || cursor[1] == 'X')) {
            base = 16;
            cursor += 2;
        } else if (cursor[0] == '0') {
            base = 8;
        } else {
            base = 10;
        }
    } else if (base == 16 && cursor[0] == '0' &&
               (cursor[1] == 'x' || cursor[1] == 'X')) {
        cursor += 2;
    }

    for (;;) {
        unsigned int digit;
        if (*cursor >= '0' && *cursor <= '9') {
            digit = (unsigned int)(*cursor - '0');
        } else if (*cursor >= 'a' && *cursor <= 'z') {
            digit = (unsigned int)(*cursor - 'a') + 10u;
        } else if (*cursor >= 'A' && *cursor <= 'Z') {
            digit = (unsigned int)(*cursor - 'A') + 10u;
        } else {
            break;
        }
        if (digit >= (unsigned int)base) {
            break;
        }
        value = value * (unsigned int)base + digit;
        ++cursor;
    }

    if (end != NULL) {
        *end = (char *)cursor;
    }
    return value;
}

int putchar(int character)
{
    uart_putc((char)character);
    return (unsigned char)character;
}
