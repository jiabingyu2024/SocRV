#include <stddef.h>

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
