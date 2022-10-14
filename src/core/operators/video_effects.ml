(*****************************************************************************

  Liquidsoap, a programmable audio stream generator.
  Copyright 2003-2022 Savonet team

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details, fully stated in the COPYING
  file at the root of the liquidsoap distribution.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

 *****************************************************************************)

open Mm
open Source

class virtual base ~name (source : source) f =
  object
    inherit operator ~name [source]
    method stype = source#stype
    method remaining = source#remaining
    method seek = source#seek
    method self_sync = source#self_sync
    method is_ready = source#is_ready
    method abort_track = source#abort_track

    method private get_frame buf =
      match VFrame.get_content buf source with
        | Some (rgb, offset, length) -> (
            try f (Content.Video.get_data rgb) offset length
            with Content.Invalid -> ())
        | _ -> ()
  end

class effect ~name (source : source) effect =
  object
    inherit
      base
        ~name source
        (fun buf off len -> Video.Canvas.iter effect buf off len)
  end

class effect_map ~name (source : source) effect =
  object
    inherit
      base ~name source (fun buf off len -> Video.Canvas.map effect buf off len)
  end

let return_t = Lang.frame_kind_t Lang.any
let () = Lang.add_module "video.alpha"

let () =
  let name = "video.greyscale" in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~return_t ~category:`Video ~descr:"Convert video to greyscale."
    (fun p ->
      let f v = List.assoc v p in
      let src = Lang.to_source (f "") in
      new effect ~name src Image.YUV420.Effect.greyscale)

let () =
  let name = "video.sepia" in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~return_t ~category:`Video ~descr:"Convert video to sepia."
    (fun p ->
      let f v = List.assoc v p in
      let src = Lang.to_source (f "") in
      new effect ~name src Image.YUV420.Effect.sepia)

let () =
  let name = "video.invert" in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~return_t ~category:`Video ~descr:"Invert video."
    (fun p ->
      let f v = List.assoc v p in
      let src = Lang.to_source (f "") in
      new effect ~name src Image.YUV420.Effect.invert)

let () =
  let name = "video.hmirror" in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~return_t ~category:`Video ~descr:"Flip image horizontally."
    (fun p ->
      let f v = List.assoc v p in
      let src = Lang.to_source (f "") in
      new effect ~name src Image.YUV420.hmirror)

let () =
  let name = "video.opacity" in
  Lang.add_operator name
    [
      ( "",
        Lang.getter_t Lang.float_t,
        None,
        Some "Coefficient to scale opacity with." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Scale opacity of video."
    (fun p ->
      let a = Lang.to_float_getter (Lang.assoc "" 1 p) in
      let src = Lang.to_source (Lang.assoc "" 2 p) in
      new effect ~name src (fun buf ->
          Image.YUV420.Effect.Alpha.scale buf (a ())))

let () =
  let name = "video.alpha.remove" in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~return_t ~category:`Video ~descr:"Remove α channel."
    (fun p ->
      let src = Lang.to_source (List.assoc "" p) in
      new effect ~name src (fun img -> Image.YUV420.fill_alpha img 0xff))

let () =
  let name = "video.fill" in
  Lang.add_operator name
    [
      ( "color",
        Lang.getter_t Lang.int_t,
        Some (Lang.int 0),
        Some "Color to fill the image with (0xRRGGBB)." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Fill frame with a color."
    (fun p ->
      let f v = List.assoc v p in
      let color = Lang.to_int_getter (f "color") in
      let src = Lang.to_source (f "") in
      let color () =
        Image.Pixel.yuv_of_rgb (Image.RGB8.Color.of_int (color ()))
      in
      new effect ~name src (fun buf ->
          Image.YUV420.fill buf (color ());
          Image.YUV420.fill_alpha buf 0xff))

let () =
  let name = "video.persistence" in
  Lang.add_operator name
    [
      ( "duration",
        Lang.getter_t Lang.float_t,
        Some (Lang.float 1.),
        Some "Persistence duration in seconds." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Make images of the video persistent."
    (fun p ->
      let duration = List.assoc "duration" p |> Lang.to_float_getter in
      let src = List.assoc "" p |> Lang.to_source in
      let fps = Lazy.force Frame.video_rate |> float_of_int in
      let prev = ref (Image.YUV420.create 0 0) in
      new effect ~name src (fun buf ->
          let duration = duration () in
          if duration > 0. then (
            let alpha = 1. -. (1. /. (duration *. fps)) in
            let alpha = int_of_float (255. *. alpha) in
            Image.YUV420.fill_alpha !prev alpha;
            Image.YUV420.add !prev buf;
            prev := Image.YUV420.copy buf)))

let () =
  let name = "video.rectangle" in
  Lang.add_operator name
    [
      ( "x",
        Lang.getter_t Lang.int_t,
        Some (Lang.int 0),
        Some "Horizontal offset." );
      ("y", Lang.getter_t Lang.int_t, Some (Lang.int 0), Some "Vertical offset.");
      ("width", Lang.getter_t Lang.int_t, None, Some "Width.");
      ("height", Lang.getter_t Lang.int_t, None, Some "Height.");
      ( "color",
        Lang.getter_t Lang.int_t,
        Some (Lang.int 0),
        Some "Color to fill the image with (0xAARRGGBB)." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Draw a rectangle."
    (fun p ->
      let x = List.assoc "x" p |> Lang.to_int_getter in
      let y = List.assoc "y" p |> Lang.to_int_getter in
      let width = List.assoc "width" p |> Lang.to_int_getter in
      let height = List.assoc "height" p |> Lang.to_int_getter in
      let color = List.assoc "color" p |> Lang.to_int_getter in
      let src = List.assoc "" p |> Lang.to_source in
      new effect_map ~name src (fun buf ->
          let x = x () in
          let y = y () in
          let width = width () in
          let height = height () in
          let c =
            color () |> Image.RGB8.Color.of_int |> Image.Pixel.yuv_of_rgb
          in
          let r = Image.YUV420.create width height in
          Image.YUV420.fill r c;
          let r = Video.Canvas.Image.make ~x ~y ~width:(-1) ~height:(-1) r in
          Video.Canvas.Image.add r buf))

let () =
  let name = "video.alpha.of_color" in
  Lang.add_operator name
    [
      ( "precision",
        Lang.float_t,
        Some (Lang.float 0.2),
        Some
          "Precision in color matching (0. means match precisely the color and \
           1. means match every color)." );
      ( "color",
        Lang.int_t,
        Some (Lang.int 0),
        Some "Color which should be transparent (in 0xRRGGBB format)." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Set a color to be transparent."
    (fun p ->
      let f v = List.assoc v p in
      let prec, color, src =
        ( Lang.to_float (f "precision"),
          Lang.to_int (f "color"),
          Lang.to_source (f "") )
      in
      let prec = int_of_float (prec *. 255.) in
      let color = Image.RGB8.Color.of_int color |> Image.Pixel.yuv_of_rgb in
      new effect ~name src (fun buf ->
          Image.YUV420.alpha_of_color buf color prec))

let () =
  let name = "video.alpha.movement" in
  Lang.add_operator name
    [
      ( "precision",
        Lang.float_t,
        Some (Lang.float 0.2),
        Some
          "Precision when comparing pixels to those of previous image (between \
           0 and 1)." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video
    ~descr:
      "Make moving parts visible and non-moving parts transparent. A cheap way \
       to have a bluescreen."
    (fun p ->
      (* let precision = List.assoc "precision" p |> Lang.to_float in *)
      let src = List.assoc "" p |> Lang.to_source in
      let prev = ref None in
      new effect ~name src (fun img ->
          (match !prev with
            | None -> ()
            | Some prev -> Image.YUV420.alpha_of_diff prev img (0xff * 2 / 10) 2);
          prev := Some img))

(*
let () =
  Lang.add_operator "video.opacity.blur"
    [
      "", Lang.source_t return_t, None, None
    ]
    ~return_t
    ~category:`Video
    ~descr:"Blur opacity of video."
    (fun p ->
       let src = Lang.to_source (Lang.assoc "" 1 p) in
         new effect src Image.YUV420.Effect.Alpha.blur)
*)

let () =
  let name = "video.lomo" in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~return_t ~category:`Video ~descr:"Emulate the \"Lomo effect\"."
    (fun p ->
      let f v = List.assoc v p in
      let src = Lang.to_source (f "") in
      new effect ~name src Image.YUV420.Effect.lomo)

let () =
  let name = "video.rotate" in
  Lang.add_operator name
    [
      ( "angle",
        Lang.getter_t Lang.float_t,
        Some (Lang.float 0.),
        Some "Angle in radians." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Rotate video."
    (fun p ->
      let a = List.assoc "angle" p |> Lang.to_float_getter in
      let s = List.assoc "" p |> Lang.to_source in
      new effect ~name s (fun buf ->
          let x = Image.YUV420.width buf / 2 in
          let y = Image.YUV420.height buf / 2 in
          Image.YUV420.rotate (Image.YUV420.copy buf) x y (a ()) buf))

let () =
  let name = "video.resize" in
  Lang.add_operator name
    [
      ( "width",
        Lang.nullable_t (Lang.getter_t Lang.int_t),
        Some Lang.null,
        Some "Target width (`null` means original width)." );
      ( "height",
        Lang.nullable_t (Lang.getter_t Lang.int_t),
        Some Lang.null,
        Some "Target height (`null` means original height)." );
      ( "proportional",
        Lang.bool_t,
        Some (Lang.bool true),
        Some "Keep original proportions." );
      ("x", Lang.getter_t Lang.int_t, Some (Lang.int 0), Some "x offset.");
      ("y", Lang.getter_t Lang.int_t, Some (Lang.int 0), Some "y offset.");
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Resize and translate video."
    (fun p ->
      let f v = List.assoc v p in
      let src = Lang.to_source (f "") in
      let width = Lang.to_valued_option Lang.to_int_getter (f "width") in
      let height = Lang.to_valued_option Lang.to_int_getter (f "height") in
      let proportional = Lang.to_bool (f "proportional") in
      let ox = Lang.to_int_getter (f "x") in
      let oy = Lang.to_int_getter (f "y") in
      let scaler = Video_converter.scaler () in
      new effect_map ~name src (fun buf ->
          let owidth = Video.Canvas.Image.width buf in
          let oheight = Video.Canvas.Image.height buf in
          let width = match width with None -> owidth | Some w -> w () in
          let height = match height with None -> oheight | Some h -> h () in
          let width, height =
            if width >= 0 && height >= 0 then (width, height)
            else if
              (* Negative values mean proportional scale. *)
              width < 0 && height < 0
            then (owidth, oheight)
            else if width < 0 then (owidth * height / oheight, height)
            else if height < 0 then (width, oheight * width / owidth)
            else assert false
          in
          buf
          |> Video.Canvas.Image.resize ~scaler ~proportional width height
          |> Video.Canvas.Image.translate (ox ()) (oy ())))

let () =
  let name = "video.opacity.box" in
  Lang.add_operator name
    [
      ("width", Lang.getter_t Lang.int_t, None, Some "Box width.");
      ("height", Lang.getter_t Lang.int_t, None, Some "Box height.");
      ("x", Lang.getter_t Lang.int_t, Some (Lang.int 0), Some "x offset.");
      ("y", Lang.getter_t Lang.int_t, Some (Lang.int 0), Some "y offset.");
      ("alpha", Lang.getter_t Lang.float_t, None, Some "alpha value.");
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video
    ~descr:"Set alpha value on a given box inside the image."
    (fun p ->
      let f v = List.assoc v p in
      let src = Lang.to_source (f "") in
      let width = Lang.to_int_getter (f "width") in
      let height = Lang.to_int_getter (f "height") in
      let ox = Lang.to_int_getter (f "x") in
      let oy = Lang.to_int_getter (f "y") in
      let alpha = Lang.to_float_getter (f "alpha") in
      new effect ~name src (fun buf ->
          Image.YUV420.box_alpha buf (ox ()) (oy ()) (width ()) (height ())
            (alpha ())))

let () =
  let name = "video.translate" in
  Lang.add_operator name
    [
      ("x", Lang.getter_t Lang.int_t, Some (Lang.int 0), Some "x offset.");
      ("y", Lang.getter_t Lang.int_t, Some (Lang.int 0), Some "y offset.");
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Translate video."
    (fun p ->
      let f v = List.assoc v p in
      let src = f "" |> Lang.to_source in
      let dx = f "x" |> Lang.to_int_getter in
      let dy = f "y" |> Lang.to_int_getter in
      new effect_map ~name src (fun buf ->
          Video.Canvas.Image.translate (dx ()) (dy ()) buf))

let () =
  let name = "video.scale" in
  Lang.add_operator name
    [
      ( "scale",
        Lang.getter_t Lang.float_t,
        Some (Lang.float 1.),
        Some "Scaling coefficient in both directions." );
      ( "xscale",
        Lang.getter_t Lang.float_t,
        Some (Lang.float 1.),
        Some "x scaling." );
      ( "yscale",
        Lang.getter_t Lang.float_t,
        Some (Lang.float 1.),
        Some "y scaling." );
      ("x", Lang.getter_t Lang.int_t, Some (Lang.int 0), Some "x offset.");
      ("y", Lang.getter_t Lang.int_t, Some (Lang.int 0), Some "y offset.");
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Scale and translate video."
    (fun p ->
      let f v = List.assoc v p in
      let src = Lang.to_source (f "") in
      let c, cx, cy, ox, oy =
        ( Lang.to_float_getter (f "scale"),
          Lang.to_float_getter (f "xscale"),
          Lang.to_float_getter (f "yscale"),
          Lang.to_int_getter (f "x"),
          Lang.to_int_getter (f "y") )
      in
      new effect_map ~name src (fun buf ->
          let c = c () in
          let cx = c *. cx () in
          let cy = c *. cy () in
          let d = 1080 in
          let cx = int_of_float ((cx *. float d) +. 0.5) in
          let cy = int_of_float ((cy *. float d) +. 0.5) in
          let scaler = Video_converter.scaler () in
          let buf = Video.Canvas.Image.scale ~scaler (cx, d) (cy, d) buf in
          Video.Canvas.Image.translate (ox ()) (oy ()) buf))

let () =
  let name = "video.line" in
  Lang.add_operator name
    [
      ( "color",
        Lang.getter_t Lang.int_t,
        Some (Lang.int 0xffffff),
        Some "Color to fill the image with (0xRRGGBB)." );
      ( "",
        Lang.getter_t (Lang.product_t Lang.int_t Lang.int_t),
        None,
        Some "Start point." );
      ( "",
        Lang.getter_t (Lang.product_t Lang.int_t Lang.int_t),
        None,
        Some "End point." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Draw a line on the video."
    (fun param ->
      let to_point_getter v =
        let v = Lang.to_getter v in
        fun () ->
          let x, y = v () |> Lang.to_product in
          (Lang.to_int x, Lang.to_int y)
      in
      let p = Lang.assoc "" 1 param |> to_point_getter in
      let q = Lang.assoc "" 2 param |> to_point_getter in
      let s = Lang.assoc "" 3 param |> Lang.to_source in
      let color = List.assoc "color" param |> Lang.to_int_getter in
      new effect_map ~name s (fun buf ->
          let r, g, b = color () |> Image.RGB8.Color.of_int in
          (* TODO: we could keep the image if the values did not change *)
          let line =
            Video.Canvas.Image.Draw.line (r, g, b, 0xff) (p ()) (q ())
          in
          Video.Canvas.Image.add line buf))

let () =
  let name = "video.render" in
  Lang.add_operator name
    [
      ( "transparent",
        Lang.bool_t,
        Some (Lang.bool true),
        Some
          "Make uncovered portions of the image transparent (they are black by \
           default)." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video
    ~descr:"Render the video by computing the result of its canvas images."
    (fun p ->
      let transparent = List.assoc "transparent" p |> Lang.to_bool in
      let s = List.assoc "" p |> Lang.to_source in
      new effect_map ~name s (fun buf ->
          Video.Canvas.Image.rendered ~transparent buf))

let () =
  let name = "video.viewport" in
  Lang.add_operator name
    [
      ("x", Lang.int_t, Some (Lang.int 0), Some "Horizontal offset.");
      ("y", Lang.int_t, Some (Lang.int 0), Some "Vertical offset.");
      ( "width",
        Lang.nullable_t Lang.int_t,
        Some Lang.null,
        Some "Width (default is frame width)." );
      ( "height",
        Lang.nullable_t Lang.int_t,
        Some Lang.null,
        Some "height (default is frame height)." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video ~descr:"Set the viewport for the current video."
    (fun p ->
      let x = List.assoc "x" p |> Lang.to_int in
      let y = List.assoc "y" p |> Lang.to_int in
      let width =
        List.assoc "width" p |> Lang.to_option |> Option.map Lang.to_int
      in
      let height =
        List.assoc "height" p |> Lang.to_option |> Option.map Lang.to_int
      in
      let s = List.assoc "" p |> Lang.to_source in
      let width =
        match width with
          | Some width -> width
          | None -> Lazy.force Frame.video_width
      in
      let height =
        match height with
          | Some height -> height
          | None -> Lazy.force Frame.video_height
      in
      new effect_map ~name s (fun buf ->
          Video.Canvas.Image.viewport ~x ~y width height buf))

let () =
  let name = "video.crop" in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~return_t ~category:`Video
    ~descr:"Make the viewport of the current video match its bounding box."
    (fun p ->
      let s = List.assoc "" p |> Lang.to_source in
      new effect_map ~name s (fun buf ->
          let (x, y), (w, h) = Video.Canvas.Image.bounding_box buf in
          Video.Canvas.Image.viewport ~x ~y w h buf))

let () =
  let name = "video.align" in
  Lang.add_operator name
    [
      ("left", Lang.bool_t, Some (Lang.bool false), Some "Align left.");
      ("right", Lang.bool_t, Some (Lang.bool false), Some "Align right.");
      ("top", Lang.bool_t, Some (Lang.bool false), Some "Align top.");
      ("bottom", Lang.bool_t, Some (Lang.bool false), Some "Align bottom.");
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:`Video
    ~descr:"Translate the video so that it is aligned on boundaries."
    (fun p ->
      let f x = List.assoc x p |> Lang.to_bool in
      let left = f "left" in
      let right = f "right" in
      let top = f "top" in
      let bottom = f "bottom" in
      let s = List.assoc "" p |> Lang.to_source in
      new effect_map ~name s (fun buf ->
          let (x, y), (w, h) = Video.Canvas.Image.bounding_box buf in
          let dx =
            if left then -x
            else if right then Video.Canvas.Image.width buf - w
            else 0
          in
          let dy =
            if top then -y
            else if bottom then Video.Canvas.Image.height buf - h
            else 0
          in
          Video.Canvas.Image.translate dx dy buf))

let () =
  let name = "video.dimensions" in
  let width = ref 0 in
  let height = ref 0 in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~meth:
      [
        ( "width",
          ([], Lang.fun_t [] Lang.int_t),
          "Width of video.",
          fun _ -> Lang.val_fun [] (fun _ -> Lang.int !width) );
        ( "height",
          ([], Lang.fun_t [] Lang.int_t),
          "Height of video.",
          fun _ -> Lang.val_fun [] (fun _ -> Lang.int !height) );
      ]
    ~return_t ~category:`Video
    ~descr:
      "Retrieve the dimensions of the video through the `width` and `height` \
       methods."
    (fun p ->
      let s = List.assoc "" p |> Lang.to_source in
      new effect_map ~name s (fun buf ->
          width := Video.Canvas.Image.width buf;
          height := Video.Canvas.Image.height buf;
          buf))

let () =
  let name = "video.alpha.to_y" in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~return_t ~category:`Video
    ~descr:
      "Convert the α channel to Y channel, thus converting opaque \
       (resp. transparent) pixels to bright (resp. dark) ones. This is useful \
       to observe the α channel."
    (fun p ->
      let s = List.assoc "" p |> Lang.to_source in
      new effect ~name s Image.YUV420.alpha_to_y)

let () =
  let name = "video.bounding_box" in
  let x = ref 0 in
  let y = ref 0 in
  let width = ref 0 in
  let height = ref 0 in
  Lang.add_operator name
    [("", Lang.source_t return_t, None, None)]
    ~meth:
      [
        ( "x",
          ([], Lang.fun_t [] Lang.int_t),
          "x offset of video.",
          fun _ -> Lang.val_fun [] (fun _ -> Lang.int !x) );
        ( "y",
          ([], Lang.fun_t [] Lang.int_t),
          "y offset of video.",
          fun _ -> Lang.val_fun [] (fun _ -> Lang.int !y) );
        ( "width",
          ([], Lang.fun_t [] Lang.int_t),
          "Width of video.",
          fun _ -> Lang.val_fun [] (fun _ -> Lang.int !width) );
        ( "height",
          ([], Lang.fun_t [] Lang.int_t),
          "Height of video.",
          fun _ -> Lang.val_fun [] (fun _ -> Lang.int !height) );
      ]
    ~return_t ~category:`Video
    ~descr:
      "Retrieve the origin (methods `x` / `y`) and the dimensions (methods \
       `width` / `height`) of the bounding box of the video."
    (fun p ->
      let s = List.assoc "" p |> Lang.to_source in
      new effect_map ~name s (fun buf ->
          let (x', y'), (w, h) = Video.Canvas.Image.bounding_box buf in
          x := x';
          y := y';
          width := w;
          height := h;
          buf))