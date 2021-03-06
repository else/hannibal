# Copyright 2012 Sentric. See LICENSE for details.

class @RegionMetricChartView extends Backbone.View
  initialize: ->
    @palette = @options.palette
    @collection.on "reset", _.bind(@render, @)
    @metricsSeries = new MetricsSeries

  render: ->
    if(@collection.isEmpty())
      @$el.html("No Data recorded yet for MetricDef #{@collection}")
    else
      @metricsSeries.populate(@collection)
      if !@graph
        @createGraph()
      else
        @updateGraph()
      @trigger "graph_rendered"

  createGraph: ->
    @graph =  new Rickshaw.Graph
      element: @$(".chart")[0],
      renderer: 'line',
      series: @metricsSeries.series
      interpolation: 'linear'

    @hoverDetail = new Rickshaw.Graph.HoverDetail
      graph: @graph
      yFormatter: ((y) => y)
      formatter: ((series, x, y, formattedX, formattedY, d) =>
        "#{series.name} : #{series.denormalize(y)} #{series.unit}"
      )

    time = new Rickshaw.Fixtures.Time()
    @xAxis = new RickshawUtil.LeftAlignedXAxis
      graph: @graph
      element: @$(".x-axis")[0]
      tickFormat: (x) ->
        d = new Date(x * 1000)
        time.formatTime(d)

    @slider = new Rickshaw.Graph.RangeSlider
      graph: @graph,
      element: @$(".slider")

    @annotator = new Rickshaw.Graph.Annotate
      graph: @graph,
      element: @$('.timeline')[0]

    @lastAddedCompactionAnnotation = 0
    @compactionsSeries = @metricsSeries.findSeries("compactions")
    @compactionsSeries.disabled = true if @compactionsSeries && @metricsSeries.series.length > 1
    @createCompactionAnnotations(@compactionsSeries) if @compactionsSeries

    @legend = new Rickshaw.Graph.Legend
      graph: @graph
      element: @$(".legend")[0]

    @shelving = new Rickshaw.Graph.Behavior.Series.Toggle
      graph: @graph
      legend: @legend

    @graph.render()

    $(".timeline").delegate(".annotation", 'mouseover',( (e) ->
      $(this).trigger("click")
    ));

    $(".timeline").delegate(".annotation", 'mouseout',( (e) ->
      $(this).trigger("click")
    ));

    @colorizeAnnotations(@compactionsSeries.color) if @compactionsSeries
    @labelYAxes()

  updateGraph: ->
    @createCompactionAnnotations(@compactionsSeries) if @compactionsSeries
    @graph.update()
    @graph.render()
    @colorizeAnnotations(@compactionsSeries.color) if @compactionsSeries
    @labelYAxes()

  createCompactionAnnotations: (compactions) ->
    compactions.noLegend = true
    metric = compactions.metric
    values = metric.getValues()
    start = Math.round(metric.getBegin())
    _(values).each (v) =>
      if v.v > 0
        start = v.ts
      else
        time = Math.round(start / 1000)
        if time > @lastAddedCompactionAnnotation
          @lastAddedCompactionAnnotation = time
          duration = Math.round((v.ts - start) / 1000)
          @annotator.add(time, "Compaction (#{duration}s)", Math.round(v.ts / 1000))

  colorizeAnnotations: (color) ->
    for ts, annotation of @annotator.data
      element = annotation.element
      if(! annotation.element )
        console.log("annotation without element!")
      else
        element.style.backgroundColor = color;
        annotation.line.style.backgroundColor = color;
        annotation.boxes.forEach( (box) ->
          if box.rangeElement then box.rangeElement.style.backgroundColor = color;
        )

  labelYAxes: ->
    _(@metricsSeries.series).each (metricSeries) ->
      name = metricSeries.name
      if metricSeries.metricName != "compactions"
        $("span:contains('#{name}')").html("#{name}: <br><span class='labelindent'>#{metricSeries.min} - #{metricSeries.max} #{metricSeries.unit}</span>")

