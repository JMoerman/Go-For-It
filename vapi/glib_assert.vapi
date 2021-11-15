/* glib-2.0.vala
 *
 * Copyright (C) 2006-2014  Jürg Billeter
 * Copyright (C) 2006-2008  Raffaele Sandrini
 * Copyright (C) 2007  Mathias Hasselmann
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * As a special exception, if you use inline functions from this file, this
 * file does not by itself cause the resulting executable to be covered by
 * the GNU Lesser General Public License.
 *
 * Author:
 * 	Jürg Billeter <j@bitron.ch>
 *	Raffaele Sandrini <rasa@gmx.ch>
 *	Mathias Hasselmann <mathias.hasselmann@gmx.de>
 */
[CCode (cprefix = "G", lower_case_cprefix = "g_", cheader_filename = "glib.h", gir_namespace = "GLib", gir_version = "2.0")]
namespace GLib {
	/** Comparison operators for use with assert_cmp*() functions */
	public enum CompareOperator {
		[CCode (cname = "==")]
		EQ,
		[CCode (cname = "!=")]
		NE,
		[CCode (cname = ">=")]
		GE,
		[CCode (cname = "<=")]
		LE,
		[CCode (cname = ">")]
		GT,
		[CCode (cname = "<")]
		LT,
	}

	[Version (since = "2.16")]
	public static void assert_cmpstr (string? a, CompareOperator op, string? b);
	[Version (since = "2.16")]
	public static void assert_cmpint (int a, CompareOperator op, int b);
	[Version (since = "2.16")]
	public static void assert_cmpuint (uint a, CompareOperator op, uint b);
	[Version (since = "2.16")]
	public static void assert_cmphex (uint a, CompareOperator op, uint b);

	/**
	 * Compare two floating-point numbers.
	 *
	 * The comparison may be done in a higher precision internally.
	 */
	[Version (since = "2.16")]
	public static void assert_cmpfloat (double a, CompareOperator op, double b);

	/** Check two floating-point numbers for equality within epsilon. */
	[Version (since = "2.58")]
	public static void assert_cmpfloat_with_epsilon (double a, double b, float epsilon);

	/** Identical to assert_cmpfloat_with_epsilon (), but with a more descriptive name. */
	[Version (since = "2.58")]
	[CCode (cname = "g_assert_cmpfloat_with_epsilon")]
	public static void assert_floateq_within_epsilon (double a, double b, float epsilon);

	[Version (since = "2.60")]
	public static void assert_cmpvariant (Variant a, Variant b);

	/** Identical to assert_cmpvariant(), but with a more descriptive name. */
	[Version (since = "2.60")]
	[CCode (cname = "g_assert_cmpvariant")]
	public static void assert_varianteq (Variant a, Variant b);
}
