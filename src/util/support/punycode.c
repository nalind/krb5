/* -*- mode: c; c-basic-offset: 4; indent-tabs-mode: nil -*- */
/* util/support/punycode.c - RFC 3492 */

#include "fake-addrinfo.h"
#include "k5-int.h"
#include "k5-unicode.h"
#include "k5-utf8.h"
#include "k5-punycode.h"

#if 0
#define debug fprintf
#else
static int
debug(FILE *fp, ...)
{
    return 0;
}
#endif

static const unsigned int delimiter = '-';
static const int base = 36;
static const int tmin = 1;
static const int tmax = 26;
static const unsigned int skew = 38;
static const unsigned int damp = 700;
static const unsigned int initial_bias = 72;
static const unsigned int initial_n = 128;

static int
adapt(long delta, int numpoints, krb5_boolean firsttime)
{
    int k;

    if (firsttime)
        delta = delta / damp;
    else
        delta = delta / 2;

    delta += (delta / numpoints);
    k = 0;
    while (delta > ((base - tmin) * tmax) / 2) {
        delta /= (base - tmin);
        k += base;
    }
    return k + (((base - tmin + 1) * delta) / (delta + skew));
}

static int
calc_t(int k, int bias)
{
    if (k <= bias + tmin)
        return tmin;
    if (k >= bias + tmax)
        return tmax;
    return k - bias;
}

static int
encode_digit(struct k5buf *buf, int digit)
{
     if (digit < 0 || digit >= base)
         return -1;
     k5_buf_add_len(buf, "abcdefghijklmnopqrstuvwxyz0123456789" + digit, 1);
     return 0;
}

ssize_t
k5int_ucs4_to_punycode(const krb5_unicode *u, size_t ulen, char **p,
                       size_t *plen)
{
    int m, n = initial_n;
    unsigned long delta = 0;
    int bias = initial_bias;
    unsigned int h, b;
    long k, q, t;
    unsigned int i;
    int i_m;
    char c;
    size_t ret;
    krb5_error_code err = 0;
    struct k5buf buf;

    *p = NULL;
    *plen = 0;
    k5_buf_init_dynamic(&buf);

    /* Encode the ASCII characters, if there are any. */
    for (i = 0; i < ulen; i++) {
        if ((unsigned long)u[i] < initial_n) {
            c = u[i];
            k5_buf_add_len(&buf, &c, 1);
            debug(stderr, "Basic char '%c'.\n", c);
        }
    }

    /* Count how many we encoded, and if there were any, add the delimiter. */
    h = b = k5_buf_len(&buf);
    if (b > 0) {
        c = delimiter;
        k5_buf_add_len(&buf, &c, 1);
        debug(stderr, "Delimiter.\n");
    }

    while (h < ulen) {
        /* Find the next lowest code point used in the input string. */
        i_m = -1;
        m = INT_MAX;
        for (i = 0; i < ulen; i++) {
            if (u[i] >= n && u[i] < m) {
                i_m = i;
                m = u[i_m];
            }
        }
        /* Something unexpected happened. */
        if (i_m < 0)
            goto cleanup;
        debug(stderr, "Next char '%#X'.\n", m);
        /* Skip over delta values that didn't include an insertion. */
        delta += (m - n) * (h + 1);
        n = m;
        /* Find the places where we insert this code point. */
        for (i = 0; i < ulen; i++) {
            if (u[i] < n || (unsigned long)u[i] < initial_n) {
                /* No insertion here, but it's in the output already. */
                delta++;
                continue;
            }
            if (u[i] == n) {
                debug(stderr, "Delta = %ld, \"%.*s\"\n", delta,
                      (int)k5_buf_len(&buf), k5_buf_data(&buf));
                /* Insert here: output the current delta. */
                q = delta;
                for (k = base; q >= (t = calc_t(k, bias)); k += base) {
                    if (encode_digit(&buf, t + ((q - t) % (base - t))) != 0)
                        goto cleanup;
                    q = (q - t) / (base - t);
                }
                if (encode_digit(&buf, q) != 0)
                    goto cleanup;
                /* Prepare for the next delta. */
                bias = adapt(delta, h + 1, h == b);
                debug(stderr, "Bias becomes %d.\n", bias);
                delta = 0;
                h++;
            }
        }
        delta++;
        n++;
    }

    ret = k5_buf_len(&buf);
    if (ret > 0) {
        *p = k5memdup0(k5_buf_data(&buf), ret, &err);
        *plen = ret;
    }

cleanup:
    k5_free_buf(&buf);
    return ret;
}

ssize_t
k5int_utf8_to_punycode(const char *utf8, size_t ulen, char **p, size_t *plen)
{
    size_t i, n_chars, ret = 0;
    krb5_unicode *ucs4;

    *p = NULL;
    *plen = 0;
    n_chars = krb5int_utf8c_chars(utf8, ulen);
    ucs4 = malloc(sizeof(*ucs4) * (n_chars + 1));
    if (ucs4 == NULL)
        return 0;
    for (i = 0; i < n_chars; i++) {
        if (krb5int_utf8_to_ucs4(utf8, ucs4 + i) != 0)
            goto cleanup;
        utf8 = krb5int_utf8_next(utf8);
    }
    ucs4[i] = 0;
    ret = k5int_ucs4_to_punycode(ucs4, n_chars, p, plen);
cleanup:
    free(ucs4);
    return ret;
}
