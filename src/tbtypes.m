;; ============================================================================= 
;; ^tbtypes - TaxisBase Types - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; ==============================================================================
INIT
	; D ^init
	D BuildCVT
	D BuildPerson
	QUIT

	
SYSAttr
	D Print^keywords("sys.attr")
	; sys.attr.abbr                      abbr
	; sys.attr.alias                     alias
	; sys.attr.cardinality               cardin
	; sys.attr.description               doc
	; sys.attr.ensure                    ensure
	; sys.attr.entattributes             entattrs
	; sys.attr.entvalidationfn             entvalid
	; sys.attr.example                   eg
	; sys.attr.exptype                   exptype
	; sys.attr.extid.code                code
	; sys.attr.homepage                  home
	; sys.attr.id                        id
	; sys.attr.indexed                   ndx
	; sys.attr.isa                       isa
	; sys.attr.key                       key
	; sys.attr.label                     label
	; sys.attr.name                      name
	; sys.attr.notes                     notes
	; sys.attr.range                     range
	; sys.attr.required                  req
	; sys.attr.resolvedby                rby
	; sys.attr.unique                    unq
	; sys.attr.usage                     use
	; sys.attr.validation                valid
	; sys.attr.wikipage                  wiki	
	QUIT


DataTypes
	D Print^keywords("sys.val")
	; sys.val.alias                      ALIAS
	; sys.val.boolean                    BOOLEAN
	; sys.val.date                       DATE
	; sys.val.datetime                   DATETIME
	; sys.val.double                     DOUBLE
	; sys.val.integer                    INT
	; sys.val.keyword                    KEYWORD
	; sys.val.langstr                    LANGSTR
	; sys.val.name                       NAME
	; sys.val.ref                        REF
	; sys.val.string                     STRING
	; sys.val.time                       TIME
	; sys.val.timestamp                  TIMESTAMP
	; sys.val.url                        URL
	; sys.val.uuid4                      UUID4				
	QUIT


BuildCVT
	W !,!,"======= Build Schema for CVT types and add attributes =========="
	K Geo
	
	S Geo(1,key)="location.cvt.geo.latitude"
	S Geo(1,range)=DOUBLE
	S Geo(1,cardin)=ONE
	S Geo(1,isa)=ATYPE
	S Geo(1,doc)="Atomic single-value attribute that stores the latitude coordinate of a geolocation, expressed in decimal degrees @en"
	S Geo(1,alias)="lat"
	S Geo(1,eg)="e.g. -36.60664 @en"
	S Geo(1,req)=1

	S Geo(2,key)="location.cvt.geo.longitude"
	S Geo(2,range)=DOUBLE
	S Geo(2,cardin)=ONE
	S Geo(2,isa)=ATYPE
	S Geo(2,doc)="Atomic single-value attribute that stores the longitude coordinate of a geolocation, expressed in decimal degrees @en"
	S Geo(2,alias)="lng"
	S Geo(2,eg)="e.g. -72.10344 @en"
	S Geo(2,req)=1

	S Geo(3,key)="location.cvt.geo.point"
	S Geo(3,range)=POINT
	S Geo(3,cardin)=ONE
	S Geo(3,isa)=ATYPE
	S Geo(3,doc)="Atomic single-value attribute that stores a geographic point encoded as the POINT Well-Known Text (WKT) representation of a 2D point (longitude, latitude) @en"
	S Geo(3,alias)="point"
	S Geo(3,eg)="e.g. POINT (-72.10344 -36.60664), WKT geo-coordinates of Chillán, Chile @en"
	S Geo(3,validfn)="$$IsPoint^utils"
	S Geo(3,req)=0

	S Geo(4,key)="location.cvt.geo.pointz"
	S Geo(4,range)=POINTZ
	S Geo(4,cardin)=ONE
	S Geo(4,isa)=ATYPE
	S Geo(4,doc)="Atomic single-value attribute that stores a geographic point encoded as the POINT Z Well-Known Text (WKT) representation of a 3D location (longitude latitude altitude) @en"
	S Geo(4,alias)="pointz"
	S Geo(4,eg)="e.g. POINT Z (-72.10344 -36.60664 140), the WKT representation of the geographic coordinates and altitude of Chillán, Chile @en"
	S Geo(4,validfn)="$$IsPointZ^utils"
	S Geo(4,req)=0

	S Geo(5,key)="location.cvt.geo.gps"
	S Geo(5,range)=GPS
	S Geo(5,cardin)=ONE
	S Geo(5,isa)=ATYPE
	S Geo(5,doc)="Atomic single-value attribute that stores a GPS geographic coordinate pair represented as latitude and longitude decimal degrees according to the WGS 84 coordinate reference system @en"
	S Geo(5,alias)="gps"
	S Geo(5,eg)="e.g. (-36.60664, -72.10344), GPS coordinates of Chillán, Chile expressed as latitude and longitude @en"
	S Geo(5,validfn)="$$IsGPS^utils"
	S Geo(5,req)=0
	
	S Geo(6,key)="location.cvt.geo.geohash"
	S Geo(6,range)=GEOHASH
	S Geo(6,cardin)=ONE
	S Geo(6,isa)=ATYPE
	S Geo(6,doc)="Atomic single-value attribute that is the geohash encoding of a geolocation, used for compact spatial indexing and proximity search @en"
	S Geo(6,alias)="geohash"
	S Geo(6,eg)="e.g. 63kxxpzyu5d, geohash of Chillán, Chile @en"
	S Geo(6,req)=0

	D Stage^sapi(.Geo)
	D Transact^sapi	

	QUIT



BuildPerson
	W !,!,"======= Build Schema for a people.persons type and add attributes =======",!
	
	S Person(1,key)="people.person"
	S Person(1,doc)="This entity represents `people.person` association type. A person association represents a human being known to have actually existed. Living persons, celebrities and politicians are persons, as are deceased persons @en"
	S Person(1,use)="Instances of person type, are back-linked to associations using the `object` type @en"	
	S Person(1,notes)="A person is distinct from a user in TaxisBase. Users have profiles and their own space to create and edit entities @en"
	S Person(1,isa)=ASSOC
	S Person(1,name)="person"
	S Person(1,label)="Person Type @en|Personne Type @fr" ; A multi-value attribute
	S Person(1,abbr)="p"
	S Person(1,alias)="PERSON"
	
	S Person(2,key)="people.person.name"
	S Person(2,range)="sys.val.name"
	S Person(2,cardin)=ONE
	S Person(2,isa)=ATYPE
	S Person(2,doc)="A single-value attribute that is the short human-readable identifier for a person @en"
	S Person(2,alias)="pname"

	S Person(3,key)="people.person.additionalName"
	S Person(3,range)=STRING
	S Person(3,cardin)=MANY
	S Person(3,isa)=ATYPE
	S Person(3,doc)="A multi-value attribute that records additional names of a person, such as middle names @en"
	S Person(3,alias)="personAdditionalName"	

	S Person(4,key)="people.person.affiliation"
	S Person(4,range)=REF
	S Person(4,cardin)=MANY
	S Person(4,isa)=ATYPE
	S Person(4,doc)="A multi-value attribute that references organizations with which a person is affiliated @en"
	S Person(4,alias)="personAffiliation"

	S Person(5,key)="people.person.alumniOf"
	S Person(5,range)=REF
	S Person(5,cardin)=MANY
	S Person(5,isa)=ATYPE
	S Person(5,doc)="A multi-value attribute that references organizations of which a person is an alumnus @en"
	S Person(5,alias)="personAlumniOf"

	S Person(6,key)="people.person.birthDate"
	S Person(6,range)=DATE
	S Person(6,cardin)=ONE
	S Person(6,isa)=ATYPE
	S Person(6,doc)="A single-value attribute that records the birth date of a person @en"
	S Person(6,alias)="personBirthDate"

	S Person(7,key)="people.person.birthPlace"
	S Person(7,range)=REF
	S Person(7,cardin)=ONE
	S Person(7,isa)=ATYPE
	S Person(7,doc)="A single-value attribute that references the place where a person was born @en"
	S Person(7,alias)="personBirthPlace"

	S Person(8,key)="people.person.child"
	S Person(8,range)=REF
	S Person(8,cardin)=MANY
	S Person(8,isa)=ATYPE
	S Person(8,doc)="A multi-value attribute that references the children of a person @en"
	S Person(8,alias)="personChild"

	S Person(9,key)="people.person.colleague"
	S Person(9,range)=REF
	S Person(9,cardin)=MANY
	S Person(9,isa)=ATYPE
	S Person(9,doc)="A multi-value attribute that references colleagues of a person @en"
	S Person(9,alias)="personColleague"

	S Person(10,key)="people.person.contactPoint"
	S Person(10,range)=REF
	S Person(10,cardin)=MANY
	S Person(10,isa)=ATYPE
	S Person(10,doc)="A multi-value attribute that references contact points for a person @en"
	S Person(10,alias)="personContactPoint"

	S Person(11,key)="people.person.deathDate"
	S Person(11,range)=DATE
	S Person(11,cardin)=ONE
	S Person(11,isa)=ATYPE
	S Person(11,doc)="A single-value attribute that records the death date of a person @en"
	S Person(11,alias)="personDeathDate"

	S Person(12,key)="people.person.deathPlace"
	S Person(12,range)=REF
	S Person(12,cardin)=ONE
	S Person(12,isa)=ATYPE
	S Person(12,doc)="A single-value attribute that references the place where a person died @en"
	S Person(12,alias)="personDeathPlace"

	S Person(13,key)="people.person.email"
	S Person(13,range)=STRING
	S Person(13,cardin)=MANY
	S Person(13,isa)=ATYPE
	S Person(13,doc)="A multi-value attribute that records the email addresses of a person @en"
	S Person(13,alias)="personEmail"

	S Person(14,key)="people.person.familyName"
	S Person(14,range)=STRING
	S Person(14,cardin)=ONE
	S Person(14,isa)=ATYPE
	S Person(14,doc)="A single-value attribute that records the family name of a person @en"
	S Person(14,alias)="personFamilyName"

	S Person(15,key)="people.person.faxNumber"
	S Person(15,range)=STRING
	S Person(15,cardin)=MANY
	S Person(15,isa)=ATYPE
	S Person(15,doc)="A multi-value attribute that records the fax numbers of a person @en"
	S Person(15,alias)="personFaxNumber"

	S Person(16,key)="people.person.follows"
	S Person(16,range)=REF
	S Person(16,cardin)=MANY
	S Person(16,isa)=ATYPE
	S Person(16,doc)="A multi-value attribute that references people followed by a person @en"
	S Person(16,alias)="personFollows"

	S Person(17,key)="people.person.givenName"
	S Person(17,range)=STRING
	S Person(17,cardin)=ONE
	S Person(17,isa)=ATYPE
	S Person(17,doc)="A single-value attribute that records the given name of a person @en"
	S Person(17,alias)="personGivenName"

	S Person(18,key)="people.person.knows"
	S Person(18,range)=REF
	S Person(18,cardin)=MANY
	S Person(18,isa)=ATYPE
	S Person(18,doc)="A multi-value attribute that references people known by a person @en"
	S Person(18,alias)="personKnows"

	S Person(19,key)="people.person.knowsAbout"
	S Person(19,range)=STRING
	S Person(19,cardin)=MANY
	S Person(19,isa)=ATYPE
	S Person(19,doc)="A multi-value attribute that records topics about which a person has knowledge or expertise @en"
	S Person(19,alias)="personKnowsAbout"

	S Person(20,key)="people.person.knowsLanguage"
	S Person(20,range)=REF
	S Person(20,cardin)=MANY
	S Person(20,isa)=ATYPE
	S Person(20,doc)="A multi-value attribute that references languages known by a person @en"
	S Person(20,alias)="personKnowsLanguage"

	S Person(21,key)="people.person.memberOf"
	S Person(21,range)=REF
	S Person(21,cardin)=MANY
	S Person(21,isa)=ATYPE
	S Person(21,doc)="A multi-value attribute that references organizations or memberships to which a person belongs @en"
	S Person(21,alias)="personMemberOf"

	S Person(22,key)="people.person.nationality"
	S Person(22,range)=REF
	S Person(22,cardin)=ONE
	S Person(22,isa)=ATYPE
	S Person(22,doc)="A single-value attribute that references the nationality of a person @en"
	S Person(22,alias)="personNationality"

	S Person(23,key)="people.person.parent"
	S Person(23,range)=REF
	S Person(23,cardin)=ONE
	S Person(23,isa)=ATYPE
	S Person(23,doc)="A single-value attribute that references a parent of a person @en"
	S Person(23,alias)="personParent"

	S Person(24,key)="people.person.relatedTo"
	S Person(24,range)=REF
	S Person(24,cardin)=MANY
	S Person(24,isa)=ATYPE
	S Person(24,doc)="A multi-value attribute that references people related to a person @en"
	S Person(24,alias)="personRelatedTo"

	S Person(25,key)="people.person.sibling"
	S Person(25,range)=REF
	S Person(25,cardin)=MANY
	S Person(25,isa)=ATYPE
	S Person(25,doc)="A multi-value attribute that references the siblings of a person @en"
	S Person(25,alias)="personSibling"

	S Person(26,key)="people.person.skills"
	S Person(26,range)=STRING
	S Person(26,cardin)=MANY
	S Person(26,isa)=ATYPE
	S Person(26,doc)="A multi-value attribute that records the skills of a person @en"
	S Person(26,alias)="personSkills"

	S Person(27,key)="people.person.spouse"
	S Person(27,range)=REF
	S Person(27,cardin)=ONE
	S Person(27,isa)=ATYPE
	S Person(27,doc)="A single-value attribute that references the spouse of a person @en"
	S Person(27,alias)="personSpouse"

	S Person(28,key)="people.person.telephone"
	S Person(28,range)=STRING
	S Person(28,cardin)=MANY
	S Person(28,isa)=ATYPE
	S Person(28,doc)="A multi-value attribute that records the telephone numbers of a person @en"
	S Person(28,alias)="personTelephone"

	S Person(29,key)="people.person.worksFor"
	S Person(29,range)=REF
	S Person(29,cardin)=MANY
	S Person(29,isa)=ATYPE
	S Person(29,doc)="A multi-value attribute that references organizations for which a person works @en"
	S Person(29,alias)="personWorksFor"	

	S Person(30,key)="people.person.address"
	S Person(30,range)=REF
	S Person(30,cardin)=MANY
	S Person(30,isa)=ATYPE
	S Person(30,doc)="A multi-value attribute that references the postal addresses associated with a person @en"
	S Person(30,alias)="personAddress"

	S Person(31,key)="people.person.address.text"
	S Person(31,range)=STRING
	S Person(31,cardin)=MANY
	S Person(31,isa)=ATYPE
	S Person(31,doc)="A multi-value attribute that records the textual representation of a person's address @en"
	S Person(31,alias)="personAddressText"
										
	D Stage^sapi(.Person)
	D Transact^sapi		
	QUIT
