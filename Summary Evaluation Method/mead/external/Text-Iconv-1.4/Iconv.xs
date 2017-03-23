/* $Id: Iconv.xs,v 1.12 2004/07/17 22:08:50 mxp Exp $ */
/* XSUB for Perl module Text::Iconv                  */
/* Copyright (c) 2004 Michael Piotrowski             */

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include <iconv.h>

/*****************************************************************************/
/* This struct represents a Text::Iconv object */

struct tiobj
{
   iconv_t handle;     /* iconv handle (returned by iconv_open()) */
   SV *retval;         /* iconv() return value (according to the Single UNIX
		          Specification, "the number of non-identical
			  conversions performed") */
   SV *raise_error;    /* Per-object flag controlling whether exceptions
                          are to be thrown */
};

/*****************************************************************************/

static int raise_error = 0;

/* Macro for checking when to throw an exception for use in the
   do_conv() function.  The logic is: Throw an exception IF
   obj->raise_error is undef AND raise_error is true OR IF
   obj->raise_error is true */
#define RAISE_ERROR_P (!SvOK(obj->raise_error) && raise_error) \
      || SvTRUE(obj->raise_error)

SV *do_conv(struct tiobj *obj, SV *string)
{
   char    *ibuf;         /* char* to the content of SV *string */
   char    *obuf;         /* temporary output buffer */
   size_t  inbytesleft;   /* no. of bytes left to convert; initially
			     this is the length of the input string,
			     and 0 when the conversion has finished */
   size_t  outbytesleft;  /* no. of bytes in the output buffer */
   size_t  l_obuf;        /* length of the output buffer */
   char    *icursor;      /* current position in the input buffer */
   /* The Single UNIX Specification (version 1 and version 2), as well
      as the HP-UX documentation from which the XPG iconv specs are
      derived, are unclear about the type of the second argument to
      iconv() (here called icursor): The manpages say const char **,
      while the header files say char **. */
   char    *ocursor;      /* current position in the output buffer */
   size_t  ret;           /* iconv() return value */
   SV      *perl_str;     /* Perl return string */

   /* Check if the input string is actually `defined'; otherwise
      simply return undef.  This is not considered an error. */

   if (! SvOK(string))
   {
      return(&PL_sv_undef);
   }
   
   perl_str = newSVpv("", 0);

   /* Get length of input string.  That's why we take an SV* instead
      of a char*: This way we can convert UCS-2 strings because we
      know their length. */

   inbytesleft = SvCUR(string);
   ibuf        = SvPV(string, inbytesleft);
   
   /* Calculate approximate amount of memory needed for the temporary
      output buffer and reserve the memory.  The idea is to choose it
      large enough from the beginning to reduce the number of copy
      operations when converting from a single-byte to a multibyte
      encoding. */
   
   if(inbytesleft <= MB_LEN_MAX)
   {
      outbytesleft = MB_LEN_MAX + 1;
   }
   else
   {
      outbytesleft = 5; /* 2 * inbytesleft; */
   }

   l_obuf = outbytesleft;

   New(0, obuf, outbytesleft, char); /* Perl malloc */
   if (obuf == NULL)
   {
      croak("New: %s", strerror(errno));
   }

   /**************************************************************************/

   icursor = ibuf;
   ocursor = obuf;

   /**************************************************************************/
   
   while(inbytesleft != 0)
   {
#if (defined(__hpux) || defined(__linux)) && ! defined(_LIBICONV_VERSION)
      /* Even in HP-UX 11.00, documentation and header files do not agree */
      /* glibc doesn't seem care too much about standards */
      ret = iconv(obj->handle, &icursor, &inbytesleft,
		                &ocursor, &outbytesleft);
#else
      ret = iconv(obj->handle, (const char **)&icursor, &inbytesleft,
		                &ocursor, &outbytesleft);
#endif

      if(ret == (size_t) -1)
      {
	 obj->retval = &PL_sv_undef;

	 switch(errno)
	 {
	    case EILSEQ:
	       /* Stop conversion if input character encountered which
		  does not belong to the input char set */
	       if (RAISE_ERROR_P)
		  croak("Character not from source char set: %s",
			strerror(errno));
	       Safefree(obuf);
	       /* INIT_SHIFT_STATE(obj->handle, ocursor, outbytesleft); */
	       return(&PL_sv_undef);
	    case EINVAL:
	       /* Stop conversion if we encounter an incomplete
                  character or shift sequence */
	       if (RAISE_ERROR_P)
		  croak("Incomplete character or shift sequence: %s",
			strerror(errno));
	       Safefree(obuf);
	       return(&PL_sv_undef);
	    case E2BIG:
	       /* fprintf(stdout, "%s\n", obuf); */

	       /* If the output buffer is not large enough, copy the
                  converted bytes to the return string, reset the
                  output buffer and continue */
	       sv_catpvn(perl_str, obuf, l_obuf - outbytesleft);
	       ocursor = obuf;
	       outbytesleft = l_obuf;
	       break;
	    default:
	       if (RAISE_ERROR_P)
		  croak("iconv error: %s", strerror(errno));
	       Safefree(obuf);
	       return(&PL_sv_undef);
	 }
      }
      else
      {
	 obj->retval = newSViv(ret);
      }
   }

   /* For state-dependent encodings, place conversion descriptor into
      initial shift state and place the byte sequence to change the
      output buffer to its initial shift state.

      The only (documented) error for this use of iconv() is E2BIG;
      here it could happen only if the output buffer has no more room
      for the reset sequence.  We can simply prevent this case by
      copying its content to the return string before calling iconv()
      (just like when E2BIG happens during the "normal" use of
      iconv(), see above).  This adds the (slight, I'd guess) overhead
      of an additional call to sv_catpvn(), but it makes the code much
      cleaner.

      Note: Since we currently don't return incomplete conversion
      results in case of EINVAL and EILSEQ, we don't have to care
      about the shift state there.  If we did return the results in
      these cases, we'd also have to reset the shift state there.
   */

   sv_catpvn(perl_str, obuf, l_obuf - outbytesleft);
   ocursor = obuf;
   outbytesleft = l_obuf;

   if((ret = iconv(obj->handle, NULL, NULL, &ocursor, &outbytesleft))
      == (size_t) -1)
   {
      croak("iconv error (while trying to reset shift state): %s",
	    strerror(errno));
      Safefree(obuf);
      return(&PL_sv_undef);
   }

   /* Copy the converted bytes to the return string, and free the
      output buffer */
   
   sv_catpvn(perl_str, obuf, l_obuf - outbytesleft);
   Safefree(obuf); /* Perl malloc */

   return perl_str;
}

typedef struct tiobj Text__Iconv;

/*****************************************************************************/
/* Perl interface                                                            */

MODULE = Text::Iconv  PACKAGE = Text::Iconv

PROTOTYPES: ENABLE

int
raise_error(...)
   CODE:
      if (items > 0 && SvIOK(ST(0))) /* if called as function */
         raise_error = SvIV(ST(0));
      if (items > 1 && SvIOK(ST(1))) /* if called as class method */
         raise_error = SvIV(ST(1));
      RETVAL = raise_error;
   OUTPUT:
      RETVAL

Text::Iconv *
new(self, fromcode, tocode)
   char *fromcode
   char *tocode
   CODE:
      iconv_t handle;
      Text__Iconv *obj;

      if ((handle = iconv_open(tocode, fromcode)) == (iconv_t)-1)
      {
	 switch(errno)
	 {
	    case ENOMEM:
	       croak("Insufficient memory to initialize conversion: %s", 
		     strerror(errno));
	    case EINVAL:
	       croak("Unsupported conversion: %s", strerror(errno));
	    default:
	       croak("Couldn't initialize conversion: %s", strerror(errno));
	 }
      }

      Newz(0, obj, 1, Text__Iconv);
      if (obj == NULL)
      {
	 croak("Newz: %s", strerror(errno));
      }

      obj->handle = handle;
      obj->retval = &PL_sv_undef;
      obj->raise_error = newSViv(0);
      sv_setsv(obj->raise_error, &PL_sv_undef);
      RETVAL = obj;
   OUTPUT:
      RETVAL

MODULE = Text::Iconv  PACKAGE = Text::IconvPtr  PREFIX = ti_

SV *
ti_convert(self, string)
   Text::Iconv *self
   SV *string
   CODE:
      RETVAL = do_conv(self, string);
   OUTPUT:
      RETVAL

SV *
ti_retval(self)
   Text::Iconv *self
   CODE:
      RETVAL = self->retval;
   OUTPUT:
      RETVAL

SV *
ti_raise_error(self, ...)
   Text::Iconv *self
   PPCODE:
      if (items > 1 && SvIOK(ST(1)))
      {
	 sv_setiv(self->raise_error, SvIV(ST(1)));
      }
      XPUSHs(sv_mortalcopy(self->raise_error));

void
ti_DESTROY(self)
   Text::Iconv * self
   CODE:
      /* printf("Now in Text::Iconv::DESTROY\n"); */
      (void) iconv_close(self->handle);
      Safefree(self);
