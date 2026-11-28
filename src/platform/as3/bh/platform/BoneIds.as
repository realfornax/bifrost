package bh.platform
{
   import flash.utils.ByteArray;
   import flash.utils.Endian;

   public final class BoneIds
   {
      public static const MOST:int = 32767;

      public static const LONGEST:int = 200;

      private static const ID:RegExp = /^[1-9][0-9]{0,4}$/;

      private static const CONTROL:RegExp = /[\x00-\x1f]/;

      private static var added:Array = [];

      private static var addedAt:Object = {};

      private static var list:Vector.<String> = null;

      private static var index:Object = null;

      public function BoneIds()
      {
         super();
      }

      private static function isMap(value:*) : Boolean
      {
         return value != null && typeof value == "object" && !(value is Array);
      }

      public static function problem(map:*, files:Array) : String
      {
         if(!isMap(map))
         {
            return "\"animationBones\" is not an object of .anm files";
         }
         for(var file:String in map)
         {
            if(files.indexOf(file) < 0)
            {
               return "\"animationBones\" names " + file + ", which \"animations\" doesn't list";
            }
            var bones:* = map[file];
            if(!isMap(bones))
            {
               return "\"animationBones\" of " + file + " is not an object of bone ids";
            }
            for(var id:String in bones)
            {
               if(!ID.test(id) || int(id) > MOST)
               {
                  return "\"animationBones\" of " + file + " has the id " + id + " (bone ids are whole numbers 1-" + MOST + ")";
               }
               var name:* = bones[id];
               if(!(name is String) || String(name).length == 0 || String(name).length > LONGEST || CONTROL.test(name))
               {
                  return "\"animationBones\" of " + file + " gives the id " + id + " no usable bone name";
               }
            }
         }
         return null;
      }

      private static function names() : Vector.<String>
      {
         var live:Vector.<String> = class_38.var_6967;
         if(live == null)
         {
            return null;
         }
         if(live !== list)
         {
            list = live;
            index = {};
            for(var i:int = live.length - 1; i >= 1; i--)
            {
               index["n" + live[i]] = i;
            }
         }
         return live;
      }

      public static function keep(report:Array) : void
      {
         if(added.length == 0 || class_38.var_6967 == null || class_38.var_6967 === list)
         {
            return;
         }
         var live:Vector.<String> = names();
         var moved:Array = [];
         for each(var name:String in added)
         {
            if(index["n" + name] == null)
            {
               live.push(name);
               index["n" + name] = live.length - 1;
            }
            if(int(index["n" + name]) != int(addedAt["n" + name]))
            {
               moved.push(name);
            }
         }
         if(moved.length > 0)
         {
            report.push("animation bones: the game reloaded its bone list and " + moved.length + " bones mods added got other ids (" +
               moved.join(", ") + "); their animations may show other art until the game restarts");
         }
      }

      public static function positions(bytes:ByteArray) : Array
      {
         var out:Array = [];
         bytes.endian = Endian.LITTLE_ENDIAN;
         bytes.position = 0;
         while(bytes.readBoolean())
         {
            bytes.readUTF();
            bytes.readUTF();
            bytes.readUTF();
            var count:uint = bytes.readUnsignedInt();
            for(var a:uint = 0; a < count; a++)
            {
               bytes.readUTF();
               var frames:uint = bytes.readUnsignedInt();
               for(var skip:int = 0; skip < 5; skip++)
               {
                  bytes.readUnsignedInt();
               }
               var extra:uint = bytes.readUnsignedInt();
               for(var e:uint = 0; e < extra; e++)
               {
                  bytes.readUnsignedInt();
               }
               var size:uint = bytes.readUnsignedInt();
               var start:uint = bytes.position;
               for(var f:uint = 0; f < frames; f++)
               {
                  frame(bytes,out);
               }
               if(bytes.position != start + size)
               {
                  throw new Error("an animation's frames take " + (bytes.position - start) + " bytes, its header says " + size);
               }
            }
         }
         return out;
      }

      private static function point(bytes:ByteArray) : void
      {
         if(bytes.readBoolean())
         {
            bytes.readDouble();
            bytes.readDouble();
         }
      }

      private static function frame(bytes:ByteArray, out:Array) : void
      {
         bytes.readShort();
         point(bytes);
         point(bytes);
         var count:int = bytes.readShort();
         for(var b:int = 0; b < count; b++)
         {
            if(bytes.readBoolean())
            {
               if(!bytes.readBoolean())
               {
                  bytes.readByte();
               }
               continue;
            }
            out.push(bytes.position);
            bytes.readShort();
            var opaque:Boolean = bytes.readBoolean();
            if(!bytes.readBoolean())
            {
               var identity:Boolean = false;
               var symmetric:Boolean = false;
               if(bytes.readBoolean())
               {
                  if(bytes.readBoolean())
                  {
                     identity = true;
                  }
                  else
                  {
                     symmetric = true;
                  }
               }
               if(!identity)
               {
                  bytes.readFloat();
                  bytes.readFloat();
                  if(!symmetric)
                  {
                     bytes.readFloat();
                     bytes.readFloat();
                  }
               }
            }
            if(!bytes.readBoolean())
            {
               bytes.readFloat();
               bytes.readFloat();
            }
            if(bytes.readBoolean())
            {
               bytes.readByte();
            }
            if(!opaque)
            {
               bytes.readUnsignedByte();
            }
         }
      }

      public static function remap(bytes:ByteArray, bones:Object, label:String, report:Array) : void
      {
         var live:Vector.<String> = names();
         if(live == null)
         {
            report.push(label + ": the game's bone list isn't loaded yet, bone ids kept as written");
            return;
         }
         var where:Array = positions(bytes);
         var to:Object = {};
         var moved:int = 0;
         var named:int = 0;
         var fresh:Array = [];
         var full:Array = [];
         for(var id:String in bones)
         {
            named++;
            var name:String = String(bones[id]);
            if(index["n" + name] == null)
            {
               if(live.length > MOST)
               {
                  full.push(name);
                  continue;
               }
               live.push(name);
               index["n" + name] = live.length - 1;
               added.push(name);
               addedAt["n" + name] = live.length - 1;
               fresh.push(name);
            }
            var at:int = int(index["n" + name]);
            if(at != int(id))
            {
               to["i" + id] = at;
               moved++;
            }
         }
         var changed:int = 0;
         var unnamed:Object = {};
         var unnamedCount:int = 0;
         for each(var pos:uint in where)
         {
            bytes.position = pos;
            var was:int = bytes.readShort();
            if(was >= 1 && bones[String(was)] == null && unnamed["i" + was] == null)
            {
               unnamed["i" + was] = true;
               unnamedCount++;
            }
            var now:* = to["i" + was];
            if(now != null)
            {
               bytes.position = pos;
               bytes.writeShort(int(now));
               changed++;
            }
         }
         bytes.position = 0;
         report.push(label + ": " + named + " bones named, " + moved + " with other ids in this game, " + changed + " of " +
            where.length + " bone ids rewritten" + (fresh.length > 0 ? ", " + fresh.length + " bones added to the game's list (" +
            fresh.join(", ") + ")" : "") + (unnamedCount > 0 ? ", " + unnamedCount + " ids it doesn't name kept as written" : "") +
            (full.length > 0 ? ", no room for " + full.join(", ") : ""));
      }
   }
}
