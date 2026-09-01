;; =============================================================================================== 
;; ^bootstrap - TBox "cold start" initial schema creation - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; ================================================================================================

INIT(MD)
;;------------------------------------------------------------------
;; Routine  : Init Procedure
;;
;; Usage    : DO INIT^bootstrap(.Metadata)	
;;
;; Purpose  : Initializes the Terminological Box (TBox) with core
;;            metadata terms definitions. Populates a local Metadata
;;            array with concept definitions conforming to the
;;            Entity-Attribute-Value (EAV) schema, to be subsequently
;;            merged into the persistent ^TBox global.;
;;
;; Scope
;;   Reads  : None
;;   Writes : MD(Ent,Attr) — Metadata local array
;;
;;
;; Parameters
;;   Metadata   : 	(OUT) Metadata Local array passed by reference
;;            		Populated with TBox concept definitions
;;            		Structure: MD(Ent, Attr) = Value
;;              		Ent  — numeric Entity ID (concept identifier)
;;              		Attr — numeric Attribute ID:
;;
;; Returns  	: 	None (result returned via MD parameter)
;;
;;------------------------------------------------------------------

	;========== Atomic Value Types ============
	S MD(120,210)="sys.val.ref"
	S MD(120,262)="Atomic Value Type representing a reference to an object. @en"
	S MD(120,270)=":db.type/ref"
	S MD(120,255)="REF"
	S MD(120,240)="Ref Value Type @en"
	S MD(120,250)="ref"
	S MD(120,299)=100

	S MD(121,210)="sys.val.keyword"
	S MD(121,262)="Atomic Value Type representing a unique, human-readable identifier for objects. @en"
	S MD(121,270)=":db.type/keyword"
	S MD(121,255)="KEYWORD"
	S MD(121,240)="Keyword Value Type @en"
	S MD(121,250)="keyword"
	S MD(121,299)=100

	S MD(122,210)="sys.val.integer"
	S MD(122,262)="Atomic Value Type representing fixed long signed integers (64bits wide). @en"
	S MD(122,270)=":db.type/long"
	S MD(122,255)="INT"
	S MD(122,240)="Integer Value Type @en"
	S MD(122,250)="integer"
	S MD(122,299)=100	

	S MD(123,210)="sys.val.string"
	S MD(123,262)="Atomic Value Type representing textual data @en"
	S MD(123,270)=":db.type/string"
	S MD(123,255)="STRING"
	S MD(123,240)="String Value Type @en"
	S MD(123,250)="string"
	S MD(123,299)=100

	S MD(124,210)="sys.val.boolean"
	S MD(124,262)="Atomic Value Type representing Boolean 0:False, 100:True @en"
	S MD(124,270)=":db.type/boolean"
	S MD(124,255)="BOOLEAN"
	S MD(124,240)="Boolean Value Type @en"
	S MD(124,250)="boolean"
	S MD(124,299)=100

	S MD(125,210)="sys.val.timestamp"
	S MD(125,262)="Atomic Value Type for Unix timestamps. Stored internally as the 0x number of microseconds since January 1, 1970 00:00:00 UTC @en"
	S MD(125,270)=":db.type/instant"
	S MD(125,255)="TIMESTAMP"
	S MD(125,240)="Timestamp Value Type @en"
	S MD(125,250)="timestamp"
	S MD(125,299)=100

	S MD(156,210)="sys.val.uuid4"
	S MD(156,262)="Atomic Value Type for UUID4 @en"
	S MD(156,270)=":db.type/uuid"
	S MD(156,255)="UUID4"
	S MD(156,240)="UUID4 Value Type @en"
	S MD(156,250)="uuid4"
	S MD(156,299)=100

	S MD(157,210)="sys.val.double"
	S MD(157,262)="Atomic Value Type representing a double-precision (64-bit) floating point number @en"
	S MD(157,270)=":db.type/double"
	S MD(157,255)="DOUBLE"
	S MD(157,240)="Double Value Type @en"
	S MD(157,250)="double"
	S MD(157,299)=100

	S MD(159,210)="sys.val.url"
	S MD(159,262)="Atomic Value Type for URLs @en"
	S MD(159,270)=":db.type/uri"
	S MD(159,255)="URL"
	S MD(159,240)="URL Value Type @en"
	S MD(159,250)="url"
	S MD(159,299)=100
	
	S MD(160,210)="sys.val.name"
	S MD(160,262)="Atomic Value Type that stores the short human-readable identifier of an entity @en"
	S MD(160,255)="NAME"
	S MD(160,240)="Name Value Type @en"
	S MD(160,250)="name"
	S MD(160,299)=100

	S MD(181,210)="sys.val.date"
	S MD(181,262)="Atomic Value Type that represents a date with year, month, day in ISO-8601 extended format @en"
	S MD(181,260)="e.g. 2026-05-07 @en"
	S MD(181,255)="DATE"
	S MD(181,240)="Date Value Type @en"
	S MD(181,250)="date"
	S MD(181,299)=100

	S MD(182,210)="sys.val.time"
	S MD(182,262)="Atomic Value Type that represents a time with hour, minute, and second in ISO-8601 format @en"
	S MD(182,260)="e.g. 18:46:25 @en"
	S MD(182,255)="TIME"
	S MD(182,240)="Time @en"
	S MD(182,250)="time"
	S MD(182,299)=100

	S MD(184,210)="sys.val.datetime"
	S MD(184,262)="Atomic Value Type for datetime in ISO-8601 format @en"
	S MD(184,260)="e.g. 2026-05-07T18:46:25.410423+02:00 @en"
	S MD(184,255)="DATETIME"
	S MD(184,240)="DateTime @en"
	S MD(184,250)="datetime"
	S MD(184,299)=100

	S MD(185,210)="sys.val.point"
	S MD(185,262)="Atomic Value Type that represents a geographic point encoded as an OGC Well-Known Text (WKT) POINT geometry with longitude and latitude coordinates @en"
	S MD(185,260)="e.g. POINT (-72.10344 -36.60664) @en"
	S MD(185,255)="POINT"
	S MD(185,240)="Point Value Type @en"
	S MD(185,250)="point"
	S MD(185,299)=100

	S MD(186,210)="sys.val.pointz"
	S MD(186,262)="Atomic Value Type that represents a geographic point encoded as an OGC Well-Known Text (WKT) POINT Z geometry with longitude, latitude, and altitude coordinates @en"
	S MD(186,260)="e.g. POINT Z (-72.10344 -36.60664 140) @en"
	S MD(186,255)="POINTZ"
	S MD(186,240)="Point Z Value Type @en"
	S MD(186,250)="pointz"
	S MD(186,299)=100

	S MD(190,210)="sys.val.alias"
	S MD(190,262)="Atomic Value Type that represents alternative, easily memorable, user-friendly references to the same entity @en"
	S MD(190,255)="ALIAS"
	S MD(190,240)="Alias Value Type @en"
	S MD(190,250)="alias"
	S MD(190,299)=100

	S MD(191,210)="sys.val.fn"
	S MD(191,262)="Atomic Value Type that stores a MUMPS extrinsic function name, distinguished by the mandatory $$Tag^Routine syntax @en"
	S MD(191,230)="Used wherever a value must point to a callable function, such as entvalidfn or validfn attributes @en"
	S MD(191,260)="e.g. $$IsInt^utils @en"
	S MD(191,255)="FN"
	S MD(191,240)="Function Name Value Type @en"
	S MD(191,250)="fn"
	S MD(191,299)=100

	S MD(192,210)="sys.val.langstr"
	S MD(192,262)="Atomic Value Type that stores a language-tagged string, distinguished from a plain string by the mandatory @<lang> suffix @en"
	S MD(192,230)="Used wherever a value can be translatable in multiple languages @en"
	S MD(192,260)="e.g. Label @en"
	S MD(192,255)="LANGSTR"
	S MD(192,240)="LanguageString Value Type @en"
	S MD(192,250)="langstr"
	S MD(192,299)=100

	S MD(193,210)="sys.val.geohash"
	S MD(193,262)="Atomic Value Type that stores a geohash encoding of a geographic position derived from latitude and longitude coordinates. @en"
	S MD(193,230)="Used for compact spatial representation, spatial indexing, proximity search, and geographic partitioning. @en"
	S MD(193,260)="e.g. 63kxxpzyu5d, geohash encoding of Chillán, Chile @en"
	S MD(193,255)="GEOHASH"
	S MD(193,240)="Geohash Value Type @en"
	S MD(193,250)="geohash"
	S MD(193,299)=100
		
	S MD(194,210)="sys.val.gps"
	S MD(194,262)="Atomic Value Type that stores a GPS geographic coordinate pair represented as latitude and longitude decimal degrees according to the WGS 84 coordinate reference system @en"
	S MD(194,230)="Used wherever a geographic position is represented using the conventional GPS notation of latitude followed by longitude. Unlike WKT POINT, which uses longitude followed by latitude, GPS values follow the human and device-oriented coordinate order (latitude, longitude). @en"
	S MD(194,260)="e.g. (-36.60664, -72.10344), GPS coordinates of Chillán, Chile @en"
	S MD(194,255)="GPS"
	S MD(194,240)="GPS Coordinate Value Type @en"
	S MD(194,250)="gps"
	S MD(194,299)=100
	

	;========= Enumerated Value Types ======================
	S MD(310,210)="sys.enum.cardinality"
	S MD(310,262)="Enumerated value type representing the set of cardinality constraints used by `sys.attr.cardinality`. Valid instances are sys.enum.cardinality.one and sys.enum.cardinality.many. @en"
	S MD(310,255)="CARDINALITY"
	S MD(310,240)="Cardinality Enumerated Type @en"
	S MD(310,250)="enum.cardinality"
	S MD(310,260)="e.g. sys.enum.cardinality.one restricts an attribute to a single value; sys.enum.cardinality.many allows multiple values @en"
	S MD(310,299)=300
	
	S MD(380,210)="sys.enum.unique"
	S MD(380,262)="Enumerated value type representing the set of uniqueness constraint used by `sys.attr.unique`. Valid instances are sys.enum.unique.insert and sys.enum.unique.upsert. @en"
	S MD(380,255)="UNIQUE"
	S MD(380,240)="Unique Enumerated Type @en"
	S MD(380,250)="enum.unique"
	S MD(380,260)="e.g. sys.enum.unique.insert enforces uniqueness on insert only; sys.enum.unique.upsert unifies incoming data with an existing entity on match @en"
	S MD(380,299)=300
	
	;========= Enumerated Values =======
	S MD(311,210)="sys.enum.cardinality.one"
	S MD(311,262)="A value representing a cardinality constraint used by `sys.attr.cardinality` to restrict an attribute to exactly one value. @en"
	S MD(311,270)=":db.cardinality/one"
	S MD(311,255)="ONE"
	S MD(311,240)="One @en"
	S MD(311,250)="one"
	S MD(311,299)=310

	S MD(317,210)="sys.enum.cardinality.many"
	S MD(317,262)="A value representing a cardinality constraint used by `sys.attr.cardinality` to allow an attribute to hold multiple values. @en"
	S MD(317,270)=":db.cardinality/many"
	S MD(317,255)="MANY"
	S MD(317,240)="Many @en"
	S MD(317,250)="many"
	S MD(317,299)=310

	S MD(383,210)="sys.enum.unique.insert"
	S MD(383,262)="A value representing a uniqueness constraint used by `sys.attr.unique` that enforces uniqueness of attribute values across entities, preventing duplicates during entity creation. @en"
	S MD(383,270)=":db.unique/value"
	S MD(383,255)="UNQINSERT"
	S MD(383,240)="Insert @en"
	S MD(383,250)="insert"
	S MD(383,299)=380

	S MD(385,210)="sys.enum.unique.upsert"
	S MD(385,262)="A value representing a uniqueness constraint used by `sys.attr.unique` that enables identity-based uniqueness, implementing upsert semantics (insert or update depending on existence). @en"
	S MD(385,270)=":db.unique/identity"
	S MD(385,255)="UNQUPSERT"
	S MD(385,240)="Upsert @en"
	S MD(385,250)="upsert"	
	S MD(385,299)=380


	;========= CVT Value Types ============================
	S MD(510,210)="location.cvt.geo"
	S MD(510,262)="Composite Value Type representing a geographic location composed of coordinate fields such as latitude, longitude, and optional elevation metadata. Instances of this entity type represent geographic positions. @en"
	S MD(510,230)="Use this CVT type to represent a geographic position as a structured value with related spatial components that must be captured together rather than as independent attributes. @en"
	S MD(510,240)="Geolocation Composite Value Type @en"
	S MD(510,250)="geo"
	S MD(510,255)="GEO"
	S MD(510,260)="e.g. latitude=-36.60664, longitude=-72.10344, altitude=140 @en"
	S MD(510,299)=500
	

	;========== Attributes ============
	S MD(201,210)="sys.attr.entspec"
	S MD(201,211)=120 ; reference value type
	S MD(201,241)=317
	S MD(201,262)="Atomic multi-value attribute that triggers enforcement of a named entity spec against the asserting entity @en"
	S MD(201,230)="Use this attribute on an entity being asserted to check required attributes present and entity predicates during staging time. The value must reference the key of a spec entity. @en"
	S MD(201,290)="sys.attr.entspec has no effect unless included explicitly in the assertion of an entity. It does not validate entities that already exist in the database. @en"
	S MD(201,270)=":db/ensure"
	S MD(201,255)="entspec"
	S MD(201,240)="Entity Validation Specification @en"
	S MD(201,250)="entspec"
	S MD(201,299)=200	

	S MD(202,210)="sys.attr.entattribute"
	S MD(202,211)=120 ; reference value type
	S MD(202,241)=317
	S MD(202,262)="Atomic multi-value attribute that specifies the set of attributes that must be present in an entity, enforced by sys.attr.entspec @en"
	S MD(202,230)="Use this when you need to validate an entity with a number of required attributes. Attach sys.attr.entattribute to a spec entity @en"
	S MD(202,270)=":db.entity/attrs"
	S MD(202,255)="entattr"
	S MD(202,240)="Entity Attribute Required @en"
	S MD(202,250)="entattribute"
	S MD(202,299)=200

	S MD(203,210)="sys.attr.entvalidationfn"
	S MD(203,211)=191 ; function name value type
	S MD(203,241)=317
	S MD(203,262)="Atomic multi-value attribute that specifies a list of fully-qualified predicates invoked by sys.attr.entspec for entity validation @en"	
	S MD(203,230)="Use this when you need to validate an entity using a set of predicate functions. Attach sys.attr.entvalidationfn to a spec entity @en"
	S MD(203,270)=":db.entity/preds"
	S MD(203,255)="entvalidfn"
	S MD(203,240)="Entity Validation Function @en"
	S MD(203,250)="entvalidationfn"
	S MD(203,299)=200

	S MD(204,210)="sys.attr.validationfn"
	S MD(204,211)=191 ; function name value type
	S MD(204,241)=317
	S MD(204,262)="Atomic multi-value attribute that defines validation predicates applied to an attribute's value when it is asserted @en"
	S MD(204,270)=":db.attr/preds"
	S MD(204,255)="validfn"
	S MD(204,240)="Attribute Validation Function @en"
	S MD(204,250)="validation"
	S MD(204,299)=200

	S MD(205,210)="sys.attr.abbr"
	S MD(205,211)=123 ; string value type
	S MD(205,241)=317
	S MD(205,262)="Atomic multi-value attribute that stores a short abbreviation for an entity @en"
	S MD(205,230)="Use this for well-known abbreviations only, not arbitrary aliases. For alternative names use sys.attr.alias instead. @en"
	S MD(205,255)="abbr"
	S MD(205,240)="Abbreviation @en"
	S MD(205,250)="abbr"
	S MD(205,299)=200
		
	S MD(210,210)="sys.attr.key"
	S MD(210,211)=121 ; keyword value type, e.g. sys.val.string
	S MD(210,241)=311
	S MD(210,242)=385
	S MD(210,262)="Atomic single-value attribute that assigns a unique, human-readable identifier to an object in its namespace @en"
	S MD(210,270)=":db/ident"
	S MD(210,255)="key"
	S MD(210,220)=1 ; IS REQUIRED to describe schema attributes
	S MD(210,240)="Key @en"
	S MD(210,250)="key"
	S MD(210,299)=200

	S MD(211,210)="sys.attr.range"
	S MD(211,211)=120 ; reference value type 
	S MD(211,241)=311
	S MD(211,262)="Atomic single-value attribute that defines the permitted value type for another attribute @en"
	S MD(211,230)="Use this to constrain the values of an attribute to a specific value type. Do not confuse range of an attribute with the domain of an attribute. @en"
	S MD(211,260)="e.g. if the value type is `sys.val.integer` then every value of the attribute must be an integer @en"
	S MD(211,270)=":db.type/valueType"
	S MD(211,255)="range"
	S MD(211,220)=1 ; IS REQUIRED to describe schema attributes
	S MD(211,240)="Range @en"
	S MD(211,250)="range"
	S MD(211,299)=200	

	S MD(220,210)="sys.attr.required"
	S MD(220,211)=124 ; boolean value type
	S MD(220,241)=311
	S MD(220,262)="Atomic single-value attribute that specifies whether another attribute is mandatory or not @en"
	S MD(220,255)="req"
	S MD(220,240)="Required @en"
	S MD(220,250)="required"
	S MD(220,299)=200

	S MD(230,210)="sys.attr.usage"
	S MD(230,211)=192 ; LANGSTR value type
	S MD(230,241)=317
	S MD(230,262)="Atomic multi-value attribute that provides guidance when and why to use a specific entity @en"
	S MD(230,230)="Attribute is not descriptive of what the entity is, but prescriptive about how it should be used @en"
	S MD(230,255)="use"
	S MD(230,240)="Usage @en"
	S MD(230,250)="usage"
	S MD(230,299)=200

	S MD(240,210)="sys.attr.label"
	S MD(240,211)=192 ; LANGSTR value type
	S MD(240,241)=317
	S MD(240,262)="Atomic multi-value attribute that provides the canonical human-readable display name for the entity, potentially translated in other languages @en"
	S MD(240,230)="It is a multi-value attribute with language tagged directly in the capitalized value using @<lang> syntax @en"
	S MD(240,255)="label"
	S MD(240,240)="Label Attribute @en"
	S MD(240,250)="label"
	S MD(240,260)="e.g. `Label @en`"
	S MD(240,299)=200

	S MD(241,210)="sys.attr.cardinality"
	S MD(241,211)=120 ; reference value type (enumerated values)
	S MD(241,241)=311
	S MD(241,262)="Enumerated single-value attribute that defines whether another attribute holds one or many values @en"
	S MD(241,270)=":db/cardinality"
	S MD(241,255)="cardin"
	S MD(241,220)=1 ; IS REQUIRED to describe schema attributes
	S MD(241,240)="Cardinality @en"
	S MD(241,250)="cardinality"
	S MD(241,299)=200
	S MD(241,280)=310 ; expected type sys.enum.cardinality

	S MD(242,210)="sys.attr.unique"
	S MD(242,211)=120 ; reference value type (enumerated values)
	S MD(242,241)=311
	S MD(242,262)="Enumerated single-value attribute that defines the uniqueness constraint behavior applied to another attribute, determining whether values are inserted as unique entries or used to unify with existing entities based on identity matching. @en"
	S MD(242,270)=":db/unique"
	S MD(242,255)="unq"
	S MD(242,220)=0 ; IS NOT REQUIRED, we put it here to register the `0` value
	S MD(242,240)="Unique @en"
	S MD(242,250)="unique"
	S MD(242,299)=200
	S MD(242,280)=380 ; expected type sys.enum.unique

	S MD(244,210)="sys.attr.indexed"
	S MD(244,211)=124 ; boolean value type
	S MD(244,241)=311
	S MD(244,262)="Atomic single-value attribute that defines whether another attribute is indexed. If true, attribute values are added to AVET index @en"
	S MD(244,270)=":db/index"
	S MD(244,255)="ndx"
	S MD(244,240)="Indexed @en"
	S MD(244,250)="indexed"
	S MD(244,299)=200	

	S MD(250,210)="sys.attr.name"
	S MD(250,211)=160 ; NAME value type
	S MD(250,241)=311
	S MD(250,262)="Atomic single-value attribute that is the short human-readable identifier for the entity, forming the last segment of its dot-notated key. @en"
	S MD(250,230)="It is used as the base from which synthetic fully-qualified names are derived across namespaces and types @en"
	S MD(250,260)="e.g. a name of `claudio_arrau` yields `sandbox.obj.claudio_arrau`, `sandbox.person.claudio_arrau`, `sandbox.pianist.claudio_arrau` and so on. @en"
	S MD(250,255)="name"
	S MD(250,240)="Name Attribute @en"
	S MD(250,250)="name"
	S MD(250,299)=200

	S MD(251,210)="sys.attr.display"
	S MD(251,211)=123 ; string value type
	S MD(251,241)=317
	S MD(251,262)="Atomic multi-value attribute that provides a generic, human-readable friendly display value for the entity @en"
	S MD(251,230)="It is a single-value plain string attribute, not language tagged, intended for generic display purposes such as coordinate summaries or composite value previews @en"
	S MD(251,255)="display"
	S MD(251,240)="Display Attribute Value @en"
	S MD(251,250)="display"
	S MD(251,260)="e.g. (lat -36.60664, lng -72.10344) @en"
	S MD(251,299)=200

	S MD(255,210)="sys.attr.alias"
	S MD(255,211)=190 ; alias value type
	S MD(255,241)=317
	S MD(255,242)=385
	S MD(255,262)="Atomic multi-value attribute that assigns one or more alternative names to an object, enabling user-friendly, searchable, and easily memorable references to the same entity. @en"
	S MD(255,255)="alias"
	S MD(255,240)="Alias @en"
	S MD(255,250)="alias"
	S MD(255,299)=200

	S MD(260,210)="sys.attr.example"
	S MD(260,211)=192 ; LANGSTR value type
	S MD(260,241)=317
	S MD(260,262)="Atomic multi-value attribute that stores one or more representative examples illustrating the typical use or expected values of the entity. @en"	
	S MD(260,230)="When you use an example, start with the prefix `e.g.` @en"
	S MD(260,240)="Example @en"
	S MD(260,250)="example"
	S MD(260,255)="eg"
	S MD(260,260)="e.g. An example must always start with the prefix `e.g` @en"
	S MD(260,299)=200

	S MD(262,210)="sys.attr.description"
	S MD(262,211)=192 ; LANGSTR value type
	S MD(262,241)=317
	S MD(262,262)="Atomic multi-value attribute that stores a human-readable description of an object, potentially translated in other languages @en"
	S MD(262,270)=":db.type/doc"
	S MD(262,255)="doc"
	S MD(262,240)="Description @en"
	S MD(262,250)="description"
	S MD(262,299)=200	

	S MD(267,210)="sys.attr.wikipage"
    S MD(267,211)=159 ; URL value type
    S MD(267,241)=317
    S MD(267,299)=200
    S MD(267,262)="The URL of a Wikipedia page that is related to an object @en"
    S MD(267,204)="$$IsURL^utils"
    S MD(267,242)=383
    S MD(267,255)="wiki"
    S MD(267,250)="wikipage"
    S MD(267,240)="Wikipage @en"
    S MD(267,230)="Atomic multi-value attribute that is used to reference Wikipedia pages related to an object. @en"    

	S MD(268,210)="sys.attr.homepage"
	S MD(268,211)=159 ; URL value type
	S MD(268,241)=311
	S MD(268,299)=200
	S MD(268,262)="The official website (homepage) of an object @en"	    
	S MD(268,204)="$$IsURL^utils"
	S MD(268,242)=383
	S MD(268,255)="home"
	S MD(268,250)="homepage"
    S MD(268,240)="Official Website @en"
	S MD(268,230)="Atomic single-value attribute used to link an object to its primary official website on the internet. @en"

	S MD(270,210)="sys.attr.extid.code"
	S MD(270,211)=123 ; string value type
	S MD(270,241)=317	
	S MD(270,242)=383
	S MD(270,262)="Atomic multi-value attribute that assigns an external identifier, vocabulary code to an object, linking it to a corresponding entity in an external database system. @en"
	S MD(270,290)="it will be replaced with an association of type b.ext.identifier @en"
	S MD(270,255)="code"
	S MD(270,240)="Code @en"
	S MD(270,250)="code"
	S MD(270,299)=200	
	
	S MD(277,210)="sys.attr.id"
	S MD(277,211)=123 ; string value type
	S MD(277,241)=311	
	S MD(277,262)="Atomic single-value attribute that identifies an existing entity only by a persisted EID generated by GENID. @en"
	S MD(277,230)="Use this attribute to identify the target entity in every Assert or Retract record. Supply a raw EID (120 characters). @en"
	S MD(277,290)="Values of sys.attr.id are not registered in the value dictionary (^TBD/^TBDR). No valkey is allocated, no SingleValueUpsert is called, and no entry appears in globals @en"	
	S MD(277,255)="id"
	S MD(277,240)="ID @en"
	S MD(277,250)="id"
	S MD(277,299)=200	
	
	S MD(279,210)="sys.attr.resolvedby"
	S MD(279,211)=121 ; keyword value type
	S MD(279,241)=311	
	S MD(279,262)="Atomic single-value attribute that identifies an entity by a unique-attribute that resolves to an existing EID. @en"
	S MD(279,230)="Use this attribute to resolve the target entity in every Assert or Retract record. Supply the attribute key of a UNQINSERT/UNQUPSERT attribute.  @en"
	S MD(279,290)="Values of sys.attr.resolvedby are not registered in the value dictionary (^TBD/^TBDR). No valkey is allocated, no SingleValueUpsert is called, and no entry appears in globals @en"	
	S MD(279,255)="rby"
	S MD(279,240)="Resolved By @en"
	S MD(279,250)="resolvedby"
	S MD(279,299)=200
	
	S MD(280,210)="sys.attr.exptype"
	S MD(280,211)=120 ; reference value type
	S MD(280,241)=317
	S MD(280,262)="Atomic multi-value attribute that constrains a reference-typed attribute by specifying expected entity types of the referenced value. @en"
	S MD(280,230)="Use this attribute alongside sys.attr.range when the range is a reference type, to further restrict which entity type the reference must point to. @en"
	S MD(280,260)="e.g. sys.attr.cardinality has range sys.val.ref and expected type sys.enum.cardinality, meaning its values must reference an instance of sys.enum.cardinality @en"
	S MD(280,255)="exptype"
	S MD(280,240)="Expected Type @en"
	S MD(280,250)="exptype"
	S MD(280,299)=200	
	
	S MD(290,210)="sys.attr.notes"
	S MD(290,211)=192 ; LANGSTR value type
	S MD(290,241)=317
	S MD(290,262)="Atomic multi-value attribute that allow storing multiple note values, each language-tagged. @en"
	S MD(290,230)="Use notes for supplemental information, implementation details, caveats, historical context, or miscellaneous remarks @en"
	S MD(290,290)="Attribute sys.attr.notes should be differentiated from sys.attr.description or sys.attr.usage. Description explains what an entity is; usage explains when and why it should be used. @en"
	S MD(290,255)="notes"
	S MD(290,240)="Notes @en"
	S MD(290,250)="notes"
	S MD(290,299)=200
	
	S MD(299,210)="sys.attr.isa"
	S MD(299,211)=120 ; reference value type
	S MD(299,241)=311
	S MD(299,262)="Atomic single-value attribute that declares the type that this entity is an instance of @en"
	S MD(299,230)="Notice that each entity belongs to only one entity type. Use an object to capture the multi-type nature of an entity @en"
	S MD(299,255)="isa"
	S MD(299,220)=1 ; IS REQUIRED to describe schema attributes
	S MD(299,240)="Isa @en"
	S MD(299,250)="isa"
	S MD(299,299)=200	
	

	;========= Abstract Types ============
	S MD(100,210)="sys.type.val"
	S MD(100,262)="A meta-level concept type whose instances denote atomic data types, whose values form the range of attributes. @en"
	S MD(100,230)="Use this entity type to create value types that can be assigned to attributes using `sys.attr.range` @en"
	S MD(100,240)="Value Type @en"
	S MD(100,250)="val"
	S MD(100,255)="DTYPE"
	S MD(100,299)=700
	
	S MD(200,210)="sys.type.attr"
	S MD(200,262)="A meta-level concept type whose instances denote properties or characteristics that can be assigned to objects. @en"
	S MD(200,230)="Use this entity type to create attributes that can be assigned to entities @en"
	S MD(200,240)="Attribute Type @en"
	S MD(200,250)="attr"
	S MD(200,255)="ATYPE"
	S MD(200,299)=700					

	S MD(300,210)="sys.type.enum"
	S MD(300,262)="A meta-level concept type whose instances denote enumerated value types, each grouping a closed set of named constants used as the range of constrained attributes. @en"
	S MD(300,230)="Use this entity type to create enumerated value types whose instances are the allowed constants. Do not use sys.type.val for enumerated types — use sys.type.enum instead. @en"
	S MD(300,240)="Enum Type @en"
	S MD(300,250)="enum"
	S MD(300,255)="ENUM"
	S MD(300,260)="e.g. sys.enum.cardinality groups sys.enum.cardinality.one and sys.enum.cardinality.many as its closed set of constants @en"
	S MD(300,299)=700


		
	S MD(500,210)="sys.type.cvt"
	S MD(500,262)="A meta-level concept type whose instances denote composite value types, where each grouping represents a single structured value, similar to a Freebase Compound Value Type. @en"
	S MD(500,230)="Use this entity type to create composite value types when a value has multiple interrelated fields (e.g. a magnitude and a unit, or a value and a date) that must be captured together rather than as separate independent attributes. @en"
	S MD(500,290)="Do not use sys.type.val for multi-field structured values, use sys.type.cvt instead. @en"
	S MD(500,240)="Composite Value Type @en"
	S MD(500,250)="cvt"
	S MD(500,255)="CVT"
	S MD(500,260)="e.g. sys.cvt.height groups a magnitude field and a unit field as the fixed set of roles composing a height value @en"
	S MD(500,299)=700
	
	
	
	S MD(700,210)="sys.type.type"
	S MD(700,262)="A meta-level concept type whose instances denote foundational entity types in TaxisBase, forming the cornerstone of TaxisBase type system. @en"
	S MD(700,230)="Use this entity type to create other fundamental entity types that are necessary for TaxisBase to function @en"
	S MD(700,240)="Type Type @en"
	S MD(700,250)="type"
	S MD(700,255)="TYPE"
	S MD(700,299)=700	
		
	S MD(800,210)="sys.type.assoc"
	S MD(800,262)="A meta-level concept type whose instances denote relationship types that collectively describe objects, analogous to relations in the Relational Model. @en"
	S MD(800,230)="Use this type to create association types for people, places, organizations, movies, and more. Use `sys.type.val` to create data types, Use `sys.type.enum` for enumerated types. @en"
	S MD(800,240)="Association Type @en"
	S MD(800,250)="assoc"
	S MD(800,255)="ASSOC"
	S MD(800,299)=700	
	
	S MD(900,210)="sys.type.obj"
	S MD(900,262)="A meta-level concept type whose instances are objects. Each object is back-linked with one or more `associations` that collectively describe the object from various perspectives @en"
	S MD(900,230)="Associations are linked to an object with the `object` attribute. @en"
	S MD(900,240)="Object Type @en"
	S MD(900,250)="obj"
	S MD(900,255)="OBJ"
	S MD(900,260)="e.g. an object to describe actor Tom Hanks. Objects in TaxisBase are used to represent a wide range of topics, including people, places, events, books, movies, and more. Object is the specific instance of any topic within TaxisBase. @en"
	S MD(900,299)=700	
	
	QUIT