@Tags = new Meteor.Collection 'tags'
@Docs = new Meteor.Collection 'docs'

if Meteor.isClient
    filter = new ReactiveArray []
    Tracker.autorun -> Meteor.subscribe 'docs', filter.array()
    Tracker.autorun -> Meteor.subscribe 'tags', filter.array()

    Accounts.ui.config
        passwordSignupFields: 'USERNAME_ONLY'


    Template.home.helpers
        docs: -> Docs.find()
        gtags: -> Tags.find {}, sort: count: -1
        filterlist: -> filter.list()

    Template.home.events
        'click .filterTag': -> filter.push @name.toString()
        'click .unfilterTag': -> filter.remove @toString()
        'click .add': -> Docs.insert {}
    Template.doc.helpers

    Template.doc.events
        'click .delete': -> Docs.remove @_id
        'click .update': (e,t) ->
            code = t.find('#code').value
            Docs.update @_id, $set: text: code
        'click .edit': ->
            Session.set
if Meteor.isServer
    Docs.allow
        insert: -> true
        update: -> true
        remove: -> true
    Meteor.publish 'docs', (filter) ->
        match = {}
        if filter.length > 0 then match.tags= $all: filter
        #Docs.find match, limit: 1
        Docs.find match

    Meteor.publish 'tags', (filter) ->
        self = @
        match = {}
        if filter.length > 0 then match.tags= $all: filter
        cloud = Docs.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: filter }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]
        cloud.forEach (tag) -> self.added 'tags', Random.id(), { name: tag.name, count:tag.count }
        self.ready()
