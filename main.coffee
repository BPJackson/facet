@Tags = new Meteor.Collection 'tags'
@Docs = new Meteor.Collection 'docs'

Meteor.methods
    removeDoc: (docId) -> Docs.remove docId

if Meteor.isClient
    tagFilter = new ReactiveArray []

    Tracker.autorun -> Meteor.subscribe 'docs', tagFilter.array()
    Tracker.autorun -> Meteor.subscribe 'tags', tagFilter.array()


    Template.home.helpers
        docs: -> Docs.find()
        globaltags: -> Tags.find {}, sort: count: -1
        tagFilterList: -> tagFilter.list()
    Template.home.events
        'click .addTagFilter': -> if tagFilter.indexOf(@name) is -1 then tagFilter.push @name.toString()
        'click .removeTagFilter': -> tagFilter.remove @toString()
        'click .removeDoc': -> Meteor.call 'removeDoc', @_id
        'submit form': (e,t) ->
            text = $('.epicarea').val()
            tags = $("[name='tags']").val()
            split = tags.split(', ')

            doc = {
                tags: split
                text: text
            }
            console.log doc

            #Docs.insert doc
            false

if Meteor.isServer
    Meteor.publish 'docs', (tagFilterArray) ->
        match = {}
        if tagFilterArray.length > 0 then match.tags= $all: tagFilterArray
        Docs.find match

    Meteor.publish 'tags', (tagFilterArray) ->
        self = @
        match = {}
        if tagFilterArray.length > 0 then match.tags= $all: tagFilterArray
        cloud = Docs.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: tagFilterArray }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]
        cloud.forEach (tag) -> self.added 'tags', Random.id(), { name: tag.name, count:tag.count }
        self.ready()

    Docs.allow
        insert: (userId, doc) -> true
        remove: (userId, doc) -> true